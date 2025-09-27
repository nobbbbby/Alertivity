import AppKit
import Darwin
import Foundation

final class SystemMetricsProvider {
    private var lastSnapshot: CPUSnapshot?
    private var lastComputedUsage: Double = 0

    func fetchMetrics() -> ActivityMetrics {
        let cpuUsage = readCPUUsage()
        let (usedMemory, totalMemory) = readMemoryUsage()
        let processCount = NSWorkspace.shared.runningApplications.count

        return ActivityMetrics(
            cpuUsage: cpuUsage,
            memoryUsed: usedMemory,
            memoryTotal: totalMemory,
            runningProcesses: processCount
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

        let snapshot = CPUSnapshot(total: totalTicks, idle: idleTicks)
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
