import AppKit
import Darwin
import Foundation

final class SystemMetricsProvider {
    private var lastSnapshot: CPUSnapshot?
    private var lastComputedUsage: Double = 0
    private var lastNetworkSnapshot: NetworkSnapshot?
    private var lastNetworkMetrics: NetworkMetrics = .zero
    private var lastHighActivityProcesses: [ProcessUsage] = []
    private var lastMetrics: ActivityMetrics = .placeholder
    private var processActivityStartTimes: [Int32: Date] = [:]
    private let highActivityProcessLimit = 12
    // Interface prefixes that are ignored to prevent counting loopback, virtual, or tunnel traffic twice.
    private let excludedInterfacePrefixes = [
        "lo", "utun", "awdl", "vmnet", "bridge", "llw", "ap", "p2p", "gif", "stf", "vnic", "tap", "tun"
    ]

    // CPU threshold (0.0 ... 1.0) a process must meet/exceed to be tracked as high activity
    var highActivityCPUThreshold: Double = 0.2

    var highActivityDuration: TimeInterval = 120 {
        didSet {
            if highActivityDuration < 0 {
                highActivityDuration = 0
                return
            }
            if abs(highActivityDuration - oldValue) > .ulpOfOne {
                processActivityStartTimes.removeAll()
                lastHighActivityProcesses = []
            }
        }
    }

    func fetchMetrics() -> ActivityMetrics {
        let timestamp = Date()
        let cpuUsage = readCPUUsage()

        let memoryUsage = readMemoryUsage()
        var usedMemory = memoryUsage?.used ?? lastMetrics.memoryUsed
        var totalMemory = memoryUsage?.total ?? lastMetrics.memoryTotal

        if usedMemory.converted(to: .bytes).value == 0, lastMetrics.hasLiveData {
            usedMemory = lastMetrics.memoryUsed
        }
        if totalMemory.converted(to: .bytes).value == 0, lastMetrics.hasLiveData {
            totalMemory = lastMetrics.memoryTotal
        }

        var processCount = NSWorkspace.shared.runningApplications.count
        if processCount == 0, lastMetrics.hasLiveData {
            processCount = lastMetrics.runningProcesses
        }

        let network = readNetworkUsage()

        var disk = readDiskUsage() ?? lastMetrics.disk
        if disk.usage == 0, lastMetrics.hasLiveData {
            disk = lastMetrics.disk
        }

        if let processes = readTopProcesses() {
            lastHighActivityProcesses = filterHighActivityProcesses(processes, at: timestamp)
        } else if !lastMetrics.highActivityProcesses.isEmpty {
            lastHighActivityProcesses = lastMetrics.highActivityProcesses
        }

        let metrics = ActivityMetrics(
            cpuUsage: cpuUsage,
            memoryUsed: usedMemory,
            memoryTotal: totalMemory,
            runningProcesses: processCount,
            network: network,
            disk: disk,
            highActivityProcesses: lastHighActivityProcesses
        )

        lastMetrics = metrics
        return metrics
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

    private func readMemoryUsage() -> (used: Measurement<UnitInformationStorage>, total: Measurement<UnitInformationStorage>)? {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &vmStat) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(vmStat.free_count + vmStat.inactive_count) * pageSize
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        let used = max(total - free, 0)

        return (
            used: Measurement(value: Double(used), unit: .bytes),
            total: Measurement(value: Double(total), unit: .bytes)
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
                if !excludedInterfacePrefixes.contains(where: { name.hasPrefix($0) }) {
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

    private func readDiskUsage() -> DiskMetrics? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
            guard
                let total = attributes[.systemSize] as? NSNumber,
                let free = attributes[.systemFreeSize] as? NSNumber
            else {
                return nil
            }

            let totalBytes = total.doubleValue
            let freeBytes = max(free.doubleValue, 0)
            let usedBytes = max(totalBytes - freeBytes, 0)

            return DiskMetrics(
                used: Measurement(value: usedBytes, unit: .bytes),
                total: Measurement(value: totalBytes, unit: .bytes)
            )
        } catch {
            return nil
        }
    }

    private func readTopProcesses() -> [ProcessUsage]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,pmem=,comm=", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let outputData = NSMutableData()
        let semaphore = DispatchSemaphore(value: 0)
        
        // Read data on background queue to prevent blocking
        DispatchQueue.global(qos: .userInitiated).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            outputData.append(data)
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        // Wait for process with timeout (2 seconds)
        let waitResult = semaphore.wait(timeout: .now() + 2.0)
        
        if waitResult == .timedOut {
            process.terminate()
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        guard let output = String(data: outputData as Data, encoding: .utf8) else {
            return nil
        }

        let lines = output.split(separator: "\n")
        var usages: [ProcessUsage] = []
        usages.reserveCapacity(highActivityProcessLimit)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4 else { continue }

            guard
                let pidValue = Int32(parts[0]),
                let cpuValue = Double(parts[1]),
                let memoryValue = Double(parts[2])
            else {
                continue
            }

            let command = String(parts[3])
            let usage = ProcessUsage(
                pid: pidValue,
                command: command,
                cpuPercent: max(cpuValue / 100, 0),
                memoryPercent: max(memoryValue / 100, 0)
            )

            guard usage.cpuPercent >= highActivityCPUThreshold else { continue }

            usages.append(usage)
            if usages.count >= highActivityProcessLimit { break }
        }

        return usages
    }

    private func filterHighActivityProcesses(_ processes: [ProcessUsage], at timestamp: Date) -> [ProcessUsage] {
        let activePIDs = Set(processes.map(\.pid))

        for pid in activePIDs {
            if processActivityStartTimes[pid] == nil {
                processActivityStartTimes[pid] = timestamp
            }
        }

        let trackedPIDs = Set(processActivityStartTimes.keys)
        for pid in trackedPIDs.subtracting(activePIDs) {
            processActivityStartTimes.removeValue(forKey: pid)
        }

        guard highActivityDuration > 0 else {
            return processes
        }

        return processes.filter { process in
            guard let start = processActivityStartTimes[process.pid] else { return false }
            return timestamp.timeIntervalSince(start) >= highActivityDuration
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
