# Language Server Protocol

## 简介

Language Server Protocol (LSP) 是一个开放的协议标准，用于实现编程语言的智能特性，如代码补全、跳转到定义、查找引用等。在Swift开发中，LSP通过SourceKit-LSP实现，为各种编辑器提供统一的语言服务支持。

## 核心功能

### 代码智能
- 代码补全
- 语法错误检查
- 类型信息提示
- 符号查找

### 代码导航
- 跳转到定义
- 查找引用
- 文档预览
- 符号列表

## 实际应用案例

### 代码补全和类型推断

以下是一个展示LSP代码补全功能的Swift示例：

```swift
struct NetworkRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    
    func send() async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// 使用示例，LSP会提供智能补全
let request = NetworkRequest(
    url: URL(string: "https://api.example.com")!,
    method: "POST",
    headers: ["Content-Type": "application/json"]
)

// 当输入request.时，LSP会提供以下补全建议：
// - send() async throws -> Data
// - url: URL
// - method: String
// - headers: [String: String]
```

### 错误诊断

```swift
protocol DataProvider {
    associatedtype DataType
    func fetchData() async throws -> DataType
}

class UserDataProvider: DataProvider {
    // LSP会标记错误：未实现必需的协议方法
    func fetchData() -> User { // 错误：缺少async throws
        return User()
    }
}

// LSP提供的错误信息：
// - Method 'fetchData()' does not match protocol requirement
// - Protocol requires 'async throws' modifiers
```

### 符号导航

```swift
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private var metrics: [String: TimeInterval] = [:]
    
    func startMeasuring(_ key: String) -> TimeInterval {
        let startTime = Date().timeIntervalSince1970
        metrics[key] = startTime
        return startTime
    }
    
    func stopMeasuring(_ key: String) -> TimeInterval? {
        guard let startTime = metrics[key] else { return nil }
        let endTime = Date().timeIntervalSince1970
        metrics.removeValue(forKey: key)
        return endTime - startTime
    }
}

// 在其他文件中使用时，LSP提供以下功能：
// 1. 跳转到定义：Command/Control + 点击符号
// 2. 查找所有引用：右键菜单 -> Find All References
// 3. 符号大纲视图：显示类的结构
```

## SourceKit-LSP配置

### 安装配置

```bash
# 安装SourceKit-LSP
brew install sourcekit-lsp

# VSCode配置示例（settings.json）
{
    "sourcekit-lsp.serverPath": "/usr/local/bin/sourcekit-lsp",
    "sourcekit-lsp.toolchainPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
}
```

### 编辑器集成

以下是VSCode的launch.json配置示例：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "sourcekit-lsp",
            "request": "launch",
            "name": "Debug Swift Package",
            "program": "${workspaceFolder}/.build/debug/YourPackage",
            "args": [],
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "swift-build"
        }
    ]
}
```

## 性能优化

### 缓存管理

```swift
class LSPCacheManager {
    static let shared = LSPCacheManager()
    private var symbolCache: [String: [SymbolOccurrence]] = [:]
    private let queue = DispatchQueue(label: "com.app.lsp.cache")
    
    func cacheSymbols(_ symbols: [SymbolOccurrence], forFile file: String) {
        queue.async {
            self.symbolCache[file] = symbols
        }
    }
    
    func getSymbols(forFile file: String) -> [SymbolOccurrence]? {
        queue.sync { symbolCache[file] }
    }
    
    func invalidateCache(forFile file: String) {
        queue.async {
            self.symbolCache.removeValue(forKey: file)
        }
    }
}

struct SymbolOccurrence {
    let name: String
    let location: SourceLocation
    let kind: SymbolKind
}
```

### 增量更新

```swift
class DocumentManager {
    private var documents: [String: Document] = [:]
    private let diffEngine = DiffEngine()
    
    func updateDocument(_ uri: String, changes: [TextDocumentContentChangeEvent]) {
        guard var document = documents[uri] else { return }
        
        for change in changes {
            // 只更新发生变化的区域
            let range = change.range
            let newText = change.text
            document.applyChange(range: range, newText: newText)
            
            // 触发增量分析
            analyzeChangedRegion(document: document, range: range)
        }
        
        documents[uri] = document
    }
    
    private func analyzeChangedRegion(document: Document, range: Range<Position>) {
        // 仅分析受影响的代码区域
        let affectedSymbols = document.findSymbolsInRange(range)
        for symbol in affectedSymbols {
            // 更新符号索引
            updateSymbolIndex(symbol)
        }
    }
}
```

## 最佳实践

### 配置优化

1. 合理设置缓存大小
2. 使用增量更新
3. 配置文件监视限制

### 性能调优

1. 限制并发请求数
2. 实现请求去重
3. 优化符号索引

### 开发流程集成

1. 编辑器配置标准化
2. 团队共享LSP设置
3. CI/CD集成检查

## 常见问题

### 问题诊断

```swift
class LSPDiagnostics {
    static func checkConfiguration() -> [DiagnosticItem] {
        var diagnostics: [DiagnosticItem] = []
        
        // 检查工具链配置
        if let toolchainPath = ProcessInfo.processInfo.environment["SOURCEKIT_TOOLCHAIN_PATH"] {
            if !FileManager.default.fileExists(atPath: toolchainPath) {
                diagnostics.append(DiagnosticItem(
                    severity: .error,
                    message: "Invalid toolchain path: \(toolchainPath)"
                ))
            }
        } else {
            diagnostics.append(DiagnosticItem(
                severity: .warning,
                message: "SOURCEKIT_TOOLCHAIN_PATH not set"
            ))
        }
        
        return diagnostics
    }
}

struct DiagnosticItem {
    enum Severity {
        case error
        case warning
        case information
    }
    
    let severity: Severity
    let message: String
}
```

## 总结

Language Server Protocol通过SourceKit-LSP为Swift开发提供了强大的语言服务支持。通过实际案例可以看出，LSP不仅提供了基础的代码智能功能，还能够通过优化配置和缓存策略提供高效的开发体验。将LSP正确集成到开发工具链中，可以显著提高开发效率和代码质量。