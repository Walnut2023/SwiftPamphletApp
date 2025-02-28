# 崩溃日志处理

## 崩溃日志基础

崩溃日志（Crash Log）是应用程序异常终止时生成的记录文件，包含了崩溃发生时的详细信息，对于排查和修复问题至关重要。

### 崩溃日志的组成部分

一个典型的iOS/macOS崩溃日志包含以下几个主要部分：

1. **头部信息**：包含应用名称、版本、设备型号、系统版本等基本信息
2. **异常信息**：崩溃的类型和原因
3. **线程回溯**：崩溃时各个线程的调用栈
4. **二进制镜像**：加载的框架和库信息
5. **设备信息**：设备状态、内存使用等

## 获取崩溃日志

### 开发阶段

在开发阶段，可以通过以下方式获取崩溃日志：

1. **Xcode直接查看**：当应用在调试模式下崩溃时，Xcode会自动显示崩溃信息
2. **设备日志**：通过Xcode的Devices and Simulators窗口查看

```swift
// 在应用中添加自定义异常处理
import Foundation

func setupCrashHandler() {
    NSSetUncaughtExceptionHandler { exception in
        print("Uncaught exception: \(exception)")
        print("Stack trace: \(exception.callStackSymbols)")
        // 可以在这里保存崩溃信息到文件或发送到服务器
    }
}
```

### 生产环境

在生产环境中，可以通过以下方式收集崩溃日志：

1. **Apple的崩溃报告系统**：通过App Store Connect查看
2. **第三方崩溃报告工具**：如Firebase Crashlytics、Bugsnag等
3. **自定义崩溃收集系统**：在下次启动时上传崩溃信息

## 崩溃日志分析

### 常见崩溃类型及原因

#### 1. 信号崩溃（Signal Crashes）

- **SIGSEGV**：内存访问违规（如访问已释放的内存）
- **SIGABRT**：程序主动终止（如调用abort()函数）
- **SIGBUS**：总线错误（如未对齐的内存访问）
- **SIGILL**：非法指令（如损坏的可执行文件）

#### 2. 异常崩溃（Exception Crashes）

- **NSRangeException**：数组越界访问
- **NSInvalidArgumentException**：传递了无效参数
- **NSUnknownKeyException**：KVC/KVO相关错误
- **EXC_BAD_ACCESS**：访问已释放或无效的内存

### 符号化崩溃日志

原始崩溃日志通常包含内存地址而非可读的函数名，需要进行符号化处理：

1. **使用Xcode自动符号化**：在Organizer中查看崩溃报告
2. **使用symbolicatecrash工具**：手动符号化崩溃日志

```bash
# 使用symbolicatecrash工具符号化崩溃日志
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
/Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/symbolicatecrash /path/to/crash.log /path/to/app.dSYM > symbolicated.log
```

## 崩溃预防与处理

### 防御性编程

```swift
// 安全地访问数组元素
extension Array {
    func safeElement(at index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// 使用示例
let array = [1, 2, 3]
if let element = array.safeElement(at: 5) {
    print(element)
} else {
    print("索引越界，但不会崩溃")
}
```

### 异常捕获

```swift
// 捕获可能的异常
func riskyOperation() {
    do {
        try performRiskyTask()
    } catch let error as NSError {
        print("捕获到错误: \(error.localizedDescription)")
        // 记录错误并优雅地恢复
    }
}
```

### 崩溃恢复

在应用重新启动时检测并处理上次崩溃：

```swift
// 在应用启动时检查上次是否崩溃
func checkForPreviousCrash() {
    let userDefaults = UserDefaults.standard
    let didCrash = userDefaults.bool(forKey: "AppDidCrashLastTime")
    
    // 设置标记，如果应用正常终止会重置这个标记
    userDefaults.set(true, forKey: "AppDidCrashLastTime")
    
    if didCrash {
        // 上次应用崩溃了，执行恢复操作
        performRecoveryActions()
    }
}

// 在应用正常终止时重置标记
func applicationWillTerminate() {
    UserDefaults.standard.set(false, forKey: "AppDidCrashLastTime")
}
```

## 崩溃监控系统

### 自定义崩溃监控

```swift
class CrashMonitor {
    static let shared = CrashMonitor()
    
    private init() {
        // 设置未捕获异常处理器
        NSSetUncaughtExceptionHandler { [weak self] exception in
            self?.handleException(exception)
        }
        
        // 设置信号处理
        signal(SIGABRT) { signal in
            CrashMonitor.shared.handleSignal(signal)
        }
        signal(SIGSEGV) { signal in
            CrashMonitor.shared.handleSignal(signal)
        }
        // 添加其他需要处理的信号...
    }
    
    private func handleException(_ exception: NSException) {
        let name = exception.name.rawValue
        let reason = exception.reason ?? "未知原因"
        let stackSymbols = exception.callStackSymbols.joined(separator: "\n")
        
        let crashLog = "异常名称: \(name)\n原因: \(reason)\n堆栈: \n\(stackSymbols)"
        saveCrashLog(crashLog)
    }
    
    private func handleSignal(_ signal: Int32) {
        let signalName = signalName(for: signal)
        var callStack = Thread.callStackSymbols.joined(separator: "\n")
        
        let crashLog = "信号: \(signalName) (\(signal))\n堆栈: \n\(callStack)"
        saveCrashLog(crashLog)
    }
    
    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGILL: return "SIGILL"
        case SIGFPE: return "SIGFPE"
        case SIGPIPE: return "SIGPIPE"
        default: return "未知信号(\(signal))"
        }
    }
    
    private func saveCrashLog(_ log: String) {
        // 保存崩溃日志到文件或其他存储
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("crash_log.txt")
            try? log.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func uploadCrashLogsIfNeeded() {
        // 检查是否有未上传的崩溃日志并上传
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("crash_log.txt")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // 读取并上传崩溃日志
                if let crashLog = try? String(contentsOf: fileURL) {
                    uploadCrashLog(crashLog)
                }
            }
        }
    }
    
    private func uploadCrashLog(_ log: String) {
        // 实现上传崩溃日志到服务器的逻辑
        // ...
        print("上传崩溃日志: \(log)")
    }
}
```

### 集成第三方崩溃报告工具

```swift
// 以Firebase Crashlytics为例
import FirebaseCrashlytics

func setupCrashlytics() {
    // 配置Crashlytics
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    
    // 记录用户信息（便于分析特定用户的崩溃）
    if let userId = UserManager.shared.currentUserId {
        Crashlytics.crashlytics().setUserID(userId)
    }
    
    // 记录自定义键值对
    Crashlytics.crashlytics().setCustomValue("premium", forKey: "user_type")
    
    // 记录非致命错误
    func logError(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
```

## 崩溃日志分析最佳实践

### 优先级排序

根据以下因素对崩溃进行优先级排序：

1. **影响用户数量**：影响更多用户的崩溃优先修复
2. **崩溃率**：高崩溃率的问题优先处理
3. **关键功能**：影响核心功能的崩溃优先解决

### 系统化分析流程

1. **收集**：确保崩溃日志完整收集
2. **分类**：按崩溃类型、设备、系统版本等分类
3. **符号化**：将内存地址转换为可读的函数名和行号
4. **分析**：确定根本原因
5. **修复**：实施修复并验证
6. **监控**：持续监控修复效果

## 总结

崩溃日志处理是应用质量保障的重要环节。通过系统化的崩溃收集、分析和修复流程，开发者可以显著提高应用的稳定性和用户体验。

有效的崩溃管理策略包括：防御性编程预防崩溃、完善的崩溃日志收集机制、系统化的分析流程以及持续的监控和改进。结合这些方法，可以构建更加健壮和可靠的应用程序。