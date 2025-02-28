# IO性能-文件读写

## 概述

高效的文件读写操作对iOS应用的性能有着重要影响。本文将介绍如何优化文件读写操作，提高应用性能。

## 最佳实践

### 1. 使用缓冲区读写

使用缓冲区可以减少IO操作次数，提高读写效率：

```swift
// 缓冲区写入示例
if let outputStream = OutputStream(url: filePath, append: false) {
    outputStream.open()
    defer { outputStream.close() }
    
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    
    // 写入数据
    for i in 0..<1000 {
        let data = "Line \(i)\n".data(using: .utf8)!
        _ = data.withUnsafeBytes { ptr in
            outputStream.write(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
        }
    }
}

// 缓冲区读取示例
if let inputStream = InputStream(url: filePath) {
    inputStream.open()
    defer { inputStream.close() }
    
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var totalBytesRead = 0
    
    while inputStream.hasBytesAvailable {
        let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
            print("读取错误")
            break
        }
        if bytesRead == 0 {
            break
        }
        totalBytesRead += bytesRead
    }
    print("总共读取: \(totalBytesRead) 字节")
}
```

### 2. 异步操作

在后台队列执行文件操作，避免阻塞主线程：

```swift
DispatchQueue.global(qos: .utility).async {
    // 执行文件读写操作
    DispatchQueue.main.async {
        // 更新UI
    }
}
```

### 3. 批量操作

合并多个小文件操作，减少IO次数：

```swift
// 批量写入示例
let fileHandle = try FileHandle(forWritingTo: filePath)
defer { fileHandle.closeFile() }

let batchSize = 1000
var dataToWrite = Data()

for i in 0..<batchSize {
    let lineData = "Line \(i)\n".data(using: .utf8)!
    dataToWrite.append(lineData)
}

fileHandle.write(dataToWrite)
```

## 性能优化要点

1. 选择合适的API
   - 小文件：Data(contentsOf:)
   - 大文件：Stream或FileHandle
   - 特殊需求：内存映射

2. 合理的缓冲区大小
   - 太小：IO次数增多
   - 太大：内存占用高
   - 建议：4KB-64KB

3. 错误处理
   - 完善的错误处理机制
   - 适当的重试策略
   - 异常恢复机制

4. 资源管理
   - 及时关闭文件
   - 正确处理文件句柄
   - 避免资源泄露

## 注意事项

1. 文件大小
   - 大文件使用流式处理
   - 避免一次性读入大文件

2. 并发访问
   - 使用同步机制
   - 避免并发写入

3. 性能监控
   - 监控IO操作耗时
   - 跟踪资源使用

## 总结

优化文件读写操作需要综合考虑多个方面，包括使用合适的API、实现缓冲区读写、采用异步操作等。同时，需要注意资源管理和并发控制，确保应用稳定高效运行。通过合理的优化策略，可以显著提升应用的文件操作性能。