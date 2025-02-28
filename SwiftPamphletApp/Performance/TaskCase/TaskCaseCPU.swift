//
//  TaskCaseCPU.swift
//  SwiftPamphletApp
//
//  Created by Ming on 2024/1/20.
//

import Foundation

extension TaskCase {
    // MARK: - CPU占用率监控示例
    static func monitorCPUUsage() {
        var totalUsageInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        // 获取第一次CPU使用数据
        let result = withUnsafeMutablePointer(to: &totalUsageInfo) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics(hostPort,
                               HOST_CPU_LOAD_INFO,
                               ptr,
                               &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = Float(totalUsageInfo.cpu_ticks.0)
            let system = Float(totalUsageInfo.cpu_ticks.1)
            let idle = Float(totalUsageInfo.cpu_ticks.2)
            let nice = Float(totalUsageInfo.cpu_ticks.3)
            
            let total = user + system + idle + nice
            let usage = (user + system) / total * 100
            
            print("CPU使用率: \(String(format: "%.1f", usage))%")
        }
    }
    
    // MARK: - CPU信息获取示例
    static func getCPUInfo() {
        var size = 0
        sysctlbyname("hw.physicalcpu", nil, &size, nil, 0)
        var physicalCPUs = 0
        sysctlbyname("hw.physicalcpu", &physicalCPUs, &size, nil, 0)
        
        sysctlbyname("hw.logicalcpu", nil, &size, nil, 0)
        var logicalCPUs = 0
        sysctlbyname("hw.logicalcpu", &logicalCPUs, &size, nil, 0)
        
        print("物理CPU核心数: \(physicalCPUs)")
        print("逻辑CPU核心数: \(logicalCPUs)")
        
        // 获取CPU类型
        var type = cpu_type_t()
        var typeSize = MemoryLayout<cpu_type_t>.size
        sysctlbyname("hw.cputype", &type, &typeSize, nil, 0)
        
        var subtype = cpu_subtype_t()
        var subtypeSize = MemoryLayout<cpu_subtype_t>.size
        sysctlbyname("hw.cpusubtype", &subtype, &subtypeSize, nil, 0)
        
        print("CPU类型: \(type)")
        print("CPU子类型: \(subtype)")
    }
    
    // MARK: - CPU占用优化示例
    static func cpuOptimizationExample() {
        // 1. 使用后台队列进行耗时操作
        let queue = DispatchQueue.global(qos: .background)
        
        // 2. 批量处理，减少CPU切换开销
        func processBatch(_ items: [Int]) {
            let batchSize = 1000
            var batch: [Int] = []
            
            for item in items {
                batch.append(item)
                
                if batch.count >= batchSize {
                    queue.async {
                        // 在后台处理一批数据
                        let result = batch.map { $0 * 2 }
                        print("处理了\(result.count)个数据")
                    }
                    batch = []
                }
            }
            
            // 处理剩余的数据
            if !batch.isEmpty {
                queue.async {
                    let result = batch.map { $0 * 2 }
                    print("处理了\(result.count)个数据")
                }
            }
        }
        
        // 3. 使用定时器控制执行频率
        var timer: Timer?
        func startPeriodicTask() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // 执行定期任务
                queue.async {
                    // 在后台执行耗时操作
                }
            }
        }
        
        // 4. 避免频繁的内存分配和释放
        let pool = NSRecursiveLock()
        var objectPool: [Any] = []
        
        func getObjectFromPool() -> Any? {
            pool.lock()
            defer { pool.unlock() }
            return objectPool.popLast()
        }
        
        func returnObjectToPool(_ object: Any) {
            pool.lock()
            defer { pool.unlock() }
            objectPool.append(object)
        }
    }
}