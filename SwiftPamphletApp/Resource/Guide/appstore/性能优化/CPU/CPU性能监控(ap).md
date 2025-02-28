# CPU性能监控

## 概述

CPU性能监控是iOS应用性能优化的关键环节，通过监控CPU使用率、负载和温度等指标，可以及时发现性能瓶颈，优化应用体验。本文介绍iOS平台上CPU性能监控的方法、工具和最佳实践。

## 监控指标

### 1. CPU使用率

CPU使用率是最基本也是最重要的监控指标，表示CPU处理任务的繁忙程度。

```swift
func monitorCPUUsage() -> Float {
    var totalUsageInfo = host_cpu_load_info()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    let hostPort = mach_host_self()
    
    let result = withUnsafeMutablePointer(to: &totalUsageInfo) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
            host_statistics(hostPort,
                           HOST_CPU_LOAD_INFO,
                           ptr,
                           &count)
        }
    }
    
    if result == KERN_SUCCESS {
        let user = Float(totalUsageInfo.cpu_ticks.0)    // 用户态使用时间
        let system = Float(totalUsageInfo.cpu_ticks.1)  // 系统态使用时间
        let idle = Float(totalUsageInfo.cpu_ticks.2)    // 空闲时间
        let nice = Float(totalUsageInfo.cpu_ticks.3)    // 优先级调度时间
        
        let total = user + system + idle + nice
        let usage = (user + system) / total * 100
        
        return usage
    }
    
    return 0.0
}
```

### 2. 实时监控实现

要实现实时监控，需要定期采样CPU使用率：

```swift
class CPUMonitor {
    private var timer: Timer?
    private var lastTotalUsageInfo: host_cpu_load_info?
    
    func startMonitoring(interval: TimeInterval = 1.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCPUUsage() {
        var totalUsageInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &totalUsageInfo) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics(hostPort,
                               HOST_CPU_LOAD_INFO,
                               ptr,
                               &count)
            }
        }
        
        if result == KERN_SUCCESS {
            if let lastInfo = lastTotalUsageInfo {
                // 计算时间差值
                let userDiff = Float(totalUsageInfo.cpu_ticks.0 - lastInfo.cpu_ticks.0)
                let systemDiff = Float(totalUsageInfo.cpu_ticks.1 - lastInfo.cpu_ticks.1)
                let idleDiff = Float(totalUsageInfo.cpu_ticks.2 - lastInfo.cpu_ticks.2)
                let niceDiff = Float(totalUsageInfo.cpu_ticks.3 - lastInfo.cpu_ticks.3)
                
                let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
                let usage = (userDiff + systemDiff) / totalDiff * 100
                
                print("实时CPU使用率: \(String(format: "%.1f", usage))%")
            }
            
            // 保存当前信息用于下次计算
            lastTotalUsageInfo = totalUsageInfo
        }
    }
}
```

### 3. 每个核心的使用率

在多核设备上，监控每个核心的使用率可以更精确地定位问题：

```swift
func monitorCPUUsagePerCore() {
    var processorInfo = processor_info_array_t(nil)
    var processorCount = natural_t(0)
    var processorMsgCount = natural_t(0)
    
    let result = host_processor_info(mach_host_self(),
                                     PROCESSOR_CPU_LOAD_INFO,
                                     &processorCount,
                                     &processorInfo,
                                     &processorMsgCount)
    
    if result == KERN_SUCCESS {
        let data = UnsafeBufferPointer(start: processorInfo, count: Int(processorCount) * Int(CPU_STATE_MAX))
        
        for i in 0..<Int(processorCount) {
            let offset = i * Int(CPU_STATE_MAX)
            let user = Float(data[offset + Int(CPU_STATE_USER)])
            let system = Float(data[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Float(data[offset + Int(CPU_STATE_IDLE)])
            let nice = Float(data[offset + Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            let usage = (user + system) / total * 100
            
            print("核心 \(i) CPU使用率: \(String(format: "%.1f", usage))%")
        }
        
        // 释放内存
        vm_deallocate(mach_task_self_,
                      vm_address_t(UnsafePointer(processorInfo).pointee),
                      vm_size_t(processorMsgCount * MemoryLayout<integer_t>.stride))
    }
}
```

## 监控阈值与告警

### 设置合理的阈值

- **普通应用**：CPU使用率持续超过50%需关注
- **游戏应用**：CPU使用率持续超过70%需关注
- **后台应用**：CPU使用率不应超过5%

### 告警实现

```swift
func checkCPUThreshold(usage: Float, threshold: Float, duration: TimeInterval) -> Bool {
    // 实现持续超过阈值的检测逻辑
    // 返回是否需要告警
    return usage > threshold
}
```

## 数据分析与可视化

### 数据收集

```swift
class CPUUsageCollector {
    var usageHistory: [Float] = []
    let maxSamples = 60 // 保存最近60个采样点
    
    func addSample(usage: Float) {
        usageHistory.append(usage)
        if usageHistory.count > maxSamples {
            usageHistory.removeFirst()
        }
    }
    
    func getAverageUsage() -> Float {
        guard !usageHistory.isEmpty else { return 0 }
        return usageHistory.reduce(0, +) / Float(usageHistory.count)
    }
    
    func getMaxUsage() -> Float {
        return usageHistory.max() ?? 0
    }
}
```

### 可视化示例

在SwiftUI中可以使用以下方式可视化CPU使用率：

```swift
struct CPUUsageView: View {
    @ObservedObject var monitor: CPUMonitorViewModel
    
    var body: some View {
        VStack {
            Text("CPU使用率: \(String(format: "%.1f", monitor.currentUsage))%")
                .font(.headline)
            
            // 使用率图表
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(monitor.usageHistory.count - 1)
                    
                    if let firstPoint = monitor.usageHistory.first {
                        path.move(to: CGPoint(x: 0, y: height - CGFloat(firstPoint / 100) * height))
                        
                        for i in 1..<monitor.usageHistory.count {
                            let point = CGPoint(
                                x: stepX * CGFloat(i),
                                y: height - CGFloat(monitor.usageHistory[i] / 100) * height
                            )
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
            }
            .frame(height: 200)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
    }
}
```

## 性能问题定位

### 常见CPU性能问题

1. **主线程阻塞**：UI卡顿，响应延迟
2. **过度计算**：复杂算法、无效计算
3. **频繁GC**：内存分配过多导致垃圾回收频繁
4. **后台任务过多**：后台线程竞争资源

### 定位方法

1. **Time Profiler**：使用Instruments的Time Profiler工具
2. **堆栈跟踪**：分析高CPU使用时的调用堆栈
3. **方法耗时统计**：

```swift
func measureExecutionTime(of block: () -> Void) -> TimeInterval {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let end = CFAbsoluteTimeGetCurrent()
    return end - start
}

// 使用示例
let time = measureExecutionTime {
    // 执行需要测量的代码
    performHeavyCalculation()
}
print("执行耗时: \(time)秒")
```

## 最佳实践

### 1. 监控策略

- **开发阶段**：详细监控，记录完整数据
- **测试阶段**：重点监控关键场景
- **生产环境**：采样监控，异常时上报

### 2. 采样频率

- **高频监控**：每0.1-0.5秒，用于精确定位问题
- **常规监控**：每1-3秒，平衡精度和性能
- **后台监控**：每5-10秒，减少资源消耗

### 3. 数据处理

- 使用滑动窗口计算平均值
- 设置合理的告警阈值
- 关联业务场景分析CPU峰值

## 工具推荐

1. **Xcode Instruments**
   - Time Profiler
   - Energy Log
   - System Trace

2. **MetricKit**
   - 系统级性能数据收集
   - 电池和性能诊断

3. **自定义监控工具**
   - 结合业务场景的定制监控
   - 特定功能的性能分析

## 总结

CPU性能监控是应用性能优化的基础，通过合理的监控策略和工具，可以及时发现并解决性能问题，提升用户体验。在实际应用中，应结合业务场景，选择合适的监控粒度和频率，平衡监控精度和监控本身带来的性能开销。