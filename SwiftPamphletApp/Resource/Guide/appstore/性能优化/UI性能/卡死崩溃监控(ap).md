# 卡死崩溃监控

在iOS应用开发中，卡死和崩溃是两种严重影响用户体验的问题。本文将介绍如何监控和处理这些问题，确保应用的稳定性和流畅性。

## 卡死与崩溃的区别

- **卡死**：应用界面完全无响应，但进程仍在运行
- **崩溃**：应用进程被系统终止，用户被强制退出应用

## 卡死监控

### 主线程监控

卡死通常是由主线程长时间阻塞导致的。我们可以通过定期检查主线程是否响应来监控卡死情况：

```swift
class MainThreadWatchdog {
    private var watchdogTimer: Timer?
    private var lastResponseTime: Date = Date()
    private let threshold: TimeInterval = 3.0 // 3秒无响应判定为卡死
    
    func start() {
        // 在后台线程创建定时器
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            // 创建定时器，每秒检查一次
            self.watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkMainThreadResponsiveness()
            }
            
            // 确保定时器在后台线程运行
            RunLoop.current.add(self.watchdogTimer!, forMode: .common)
            RunLoop.current.run()
        }
        
        // 在主线程定期更新响应时间
        DispatchQueue.main.async { [weak self] in
            self?.updateResponseTime()
        }
    }
    
    func stop() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
    
    private func updateResponseTime() {
        lastResponseTime = Date()
        
        // 递归调用，确保主线程持续更新时间戳
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateResponseTime()
        }
    }
    
    private func checkMainThreadResponsiveness() {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastResponseTime)
        
        if timeInterval > threshold {
            // 检测到卡死
            reportMainThreadStall(duration: timeInterval)
        }
    }
    
    private func reportMainThreadStall(duration: TimeInterval) {
        // 获取主线程堆栈
        let stackTrace = captureMainThreadCallStack()
        
        // 记录卡死信息
        print("检测到主线程卡死！持续时间: \(duration)秒")
        print("主线程堆栈: \(stackTrace)")
        
        // 在实际应用中，可以将信息上报到服务器
    }
    
    private func captureMainThreadCallStack() -> [String] {
        // 实际项目中需要使用私有API或第三方库获取堆栈
        // 这里仅作示例，返回空数组
        return []
    }
}
```

### 使用心跳机制

另一种监控卡死的方法是使用心跳机制，定期在主线程和后台线程之间传递信号：

```swift
class HeartbeatMonitor {
    private var heartbeatTimer: Timer?
    private var monitorTimer: Timer?
    private var lastHeartbeatTime: Date = Date()
    private let threshold: TimeInterval = 3.0
    
    func start() {
        // 在主线程发送心跳
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.heartbeat()
        }
        
        // 在后台线程监控心跳
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkHeartbeat()
            }
            
            RunLoop.current.add(self.monitorTimer!, forMode: .common)
            RunLoop.current.run()
        }
    }
    
    func stop() {
        heartbeatTimer?.invalidate()
        monitorTimer?.invalidate()
        heartbeatTimer = nil
        monitorTimer = nil
    }
    
    private func heartbeat() {
        lastHeartbeatTime = Date()
    }
    
    private func checkHeartbeat() {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastHeartbeatTime)
        
        if timeInterval > threshold {
            // 检测到卡死
            reportStall(duration: timeInterval)
        }
    }
    
    private func reportStall(duration: TimeInterval) {
        print("检测到应用卡死！持续时间: \(duration)秒")
        // 在实际应用中，可以收集更多信息并上报
    }
}
```

## 崩溃监控

### 使用系统崩溃报告

在iOS中，可以通过注册`NSSetUncaughtExceptionHandler`来捕获未处理的异常：

```swift
class CrashMonitor {
    static func register() {
        // 设置未捕获异常处理器
        NSSetUncaughtExceptionHandler { exception in
            // 收集崩溃信息
            let name = exception.name.rawValue
            let reason = exception.reason ?? "未知原因"
            let callStack = exception.callStackSymbols.joined(separator: "\n")
            
            // 保存崩溃日志
            self.saveCrashLog(name: name, reason: reason, callStack: callStack)
        }
        
        // 注册信号处理
        self.registerSignalHandler()
    }
    
    private static func registerSignalHandler() {
        // 监听常见的崩溃信号
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE]
        
        for signal in signals {
            signal_t.init(signal) { signal in
                // 收集信号崩溃信息
                let info = "收到信号: \(signal)"
                let callStack = Thread.callStackSymbols.joined(separator: "\n")
                
                // 保存崩溃日志
                self.saveCrashLog(name: "Signal Crash", reason: info, callStack: callStack)
                
                // 退出程序
                exit(1)
            }
        }
    }
    
    private static func saveCrashLog(name: String, reason: String, callStack: String) {
        // 构建崩溃日志内容
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let deviceInfo = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        let appInfo = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知版本"
        
        let crashLog = """
        时间: \(timestamp)
        应用版本: \(appInfo)
        设备信息: \(deviceInfo)
        异常名称: \(name)
        异常原因: \(reason)
        堆栈信息:
        \(callStack)
        """
        
        // 保存到文件
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("crash_\(timestamp).log")
            try crashLog.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("保存崩溃日志失败: \(error)")
        }
    }
}
```

### 在SwiftTestApp中应用

在SwiftTestApp项目中，我们可以在应用启动时初始化监控：

```swift
// 在AppDelegate中
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 注册崩溃监控
    CrashMonitor.register()
    
    // 启动卡死监控
    let watchdog = MainThreadWatchdog()
    watchdog.start()
    
    return true
}
```

## 数据分析与优化

收集到卡死和崩溃数据后，我们可以进行以下分析：

1. **崩溃率统计**：计算应用的崩溃率，监控趋势变化
2. **热点识别**：找出最常见的崩溃和卡死场景
3. **版本对比**：比较不同版本之间的稳定性变化
4. **设备相关性**：分析是否与特定设备或系统版本相关

## 优化建议

### 防止卡死

1. **避免主线程阻塞**：将耗时操作移至后台线程
2. **使用异步API**：优先使用异步API处理网络请求和IO操作
3. **分解大任务**：将大型计算任务分解为小块，避免长时间占用CPU

### 防止崩溃

1. **健壮的错误处理**：使用do-catch和可选值安全解包
2. **防御性编程**：检查边界条件和异常情况
3. **内存管理**：避免内存泄漏和过度使用内存

## 总结

卡死和崩溃监控是保障应用质量的重要手段。通过实时监控主线程状态、捕获未处理异常和信号崩溃，我们可以及时发现并解决潜在问题，提升应用的稳定性和用户体验。在SwiftTestApp项目中，合理应用这些监控技术，可以帮助我们构建更加健壮的应用。
