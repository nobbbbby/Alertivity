import AppKit
import Darwin
import Foundation

final class SystemMetricsProvider {
    private var lastSnapshot: CPUSnapshot?
    private var lastComputedUsage: Double = 0
    private var lastNetworkSnapshot: NetworkSnapshot?
    private var lastNetworkMetrics: NetworkMetrics = .zero

    func fetchMetrics() -> ActivityMetrics {
        let cpuUsage = readCPUUsage()
        let (usedMemory, totalMemory) = readMemoryUsage()
        let processCount = NSWorkspace.shared.runningApplications.count
        let network = readNetworkUsage()
        let disk = readDiskUsage()

        return ActivityMetrics(
            cpuUsage: cpuUsage,
            memoryUsed: usedMemory,
            memoryTotal: totalMemory,
            runningProcesses: processCount,
            network: network,
            disk: disk
        )
    }

    private func readCPUUsage() -> Double {
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return lastComputedUsage
        }

        defer {
            let pointer = vm_address_t(bitPattern: info)
            vm_deallocate(mach_task_self_, pointer, vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        let cpuStates = UnsafeBufferPointer(start: info, count: Int(processorInfoCount))
        let stride = Int(CPU_STATE_MAX)

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for processorIndex in 0..<Int(processorCount) {
            let base = processorIndex * stride
            idleTicks += UInt64(cpuStates[base + Int(CPU_STATE_IDLE)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_USER)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_SYSTEM)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_NICE)])
            totalTicks += UInt64(cpuStates[base + Int(CPU_STATE_IDLE)])
        }

        let snapshot = CPUSnapshot(totalTicks: totalTicks, idleTicks: idleTicks)
        let usage = snapshot.usage(relativeTo: lastSnapshot)
        lastSnapshot = snapshot
        lastComputedUsage = usage
        return usage
    }

    private func readMemoryUsage() -> (Measurement<UnitInformationStorage>, Measurement<UnitInformationStorage>) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &vmStat) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            let totalMemory = Measurement(value: Double(ProcessInfo.processInfo.physicalMemory), unit: UnitInformationStorage.bytes)
            return (.init(value: 0, unit: .bytes), totalMemory)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(vmStat.free_count + vmStat.inactive_count) * pageSize
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        let used = max(total - free, 0)

        return (
            Measurement(value: Double(used), unit: .bytes),
            Measurement(value: Double(total), unit: .bytes)
        )
    }

    private func readNetworkUsage() -> NetworkMetrics {
        guard let snapshot = captureNetworkSnapshot() else {
            return lastNetworkMetrics
        }

        guard let previousSnapshot = lastNetworkSnapshot else {
            lastNetworkSnapshot = snapshot
            lastNetworkMetrics = .zero
            return .zero
        }

        lastNetworkSnapshot = snapshot

        let interval = snapshot.timestamp.timeIntervalSince(previousSnapshot.timestamp)
        guard interval > 0 else {
            return lastNetworkMetrics
        }

        let receivedDelta: UInt64
        if snapshot.receivedBytes >= previousSnapshot.receivedBytes {
            receivedDelta = snapshot.receivedBytes - previousSnapshot.receivedBytes
        } else {
            receivedDelta = snapshot.receivedBytes
        }

        let sentDelta: UInt64
        if snapshot.sentBytes >= previousSnapshot.sentBytes {
            sentDelta = snapshot.sentBytes - previousSnapshot.sentBytes
        } else {
            sentDelta = snapshot.sentBytes
        }

        let metrics = NetworkMetrics(
            receivedBytesPerSecond: Double(receivedDelta) / interval,
            sentBytesPerSecond: Double(sentDelta) / interval
        )

        lastNetworkMetrics = metrics
        return metrics
    }

    private func captureNetworkSnapshot() -> NetworkSnapshot? {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return nil
        }

        defer {
            freeifaddrs(firstAddress)
        }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer?.pointee {
            if
                let address = current.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let dataPointer = unsafeBitCast(current.ifa_data, to: UnsafeMutablePointer<if_data>?.self)
            {
                let name = String(cString: current.ifa_name)
                if !name.hasPrefix("lo") {
                    received &+= UInt64(dataPointer.pointee.ifi_ibytes)
                    sent &+= UInt64(dataPointer.pointee.ifi_obytes)
                }
            }

            pointer = current.ifa_next
        }

        return NetworkSnapshot(
            receivedBytes: received,
            sentBytes: sent,
            timestamp: Date()
        )
    }

    private func readDiskUsage() -> DiskMetrics {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
            guard
                let total = attributes[.systemSize] as? NSNumber,
                let free = attributes[.systemFreeSize] as? NSNumber
            else {
                return .placeholder
            }

            let totalBytes = total.doubleValue
            let freeBytes = max(free.doubleValue, 0)
            let usedBytes = max(totalBytes - freeBytes, 0)

            return DiskMetrics(
                used: Measurement(value: usedBytes, unit: .bytes),
                total: Measurement(value: totalBytes, unit: .bytes)
            )
        } catch {
            return .placeholder
        }
    }
}

private struct CPUSnapshot {
    let totalTicks: UInt64
    let idleTicks: UInt64

    func usage(relativeTo previous: CPUSnapshot?) -> Double {
        guard let previous else { return 0 }

        let totalDelta = Double(totalTicks) - Double(previous.totalTicks)
        let idleDelta = Double(idleTicks) - Double(previous.idleTicks)
        guard totalDelta > 0 else { return 0 }

        let busy = totalDelta - idleDelta
        return max(0, min(1, busy / totalDelta))
    }
}

private struct NetworkSnapshot {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: Date
}
