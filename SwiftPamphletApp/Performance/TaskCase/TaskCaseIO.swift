//
//  TaskCaseIO.swift
//  SwiftPamphletApp
//
//  Created by Ming on 2024/1/20.
//

import Foundation

extension TaskCase {
    // MARK: - 文件系统操作示例
    static func fileSystemOperations() {
        // 获取文件系统信息
        let fileManager = FileManager.default
        do {
            let documentPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentPath.path)
            
            // 获取可用空间
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                print("可用空间: \(ByteCountFormatter.string(fromByteCount: freeSize.int64Value, countStyle: .file))")
            }
            
            // 获取总空间
            if let totalSize = attributes[.systemSize] as? NSNumber {
                print("总空间: \(ByteCountFormatter.string(fromByteCount: totalSize.int64Value, countStyle: .file))")
            }
        } catch {
            print("获取文件系统信息失败: \(error)")
        }
    }
    
    // MARK: - 文件读写优化示例
    static func optimizedFileOperations() {
        let fileManager = FileManager.default
        let documentPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentPath.appendingPathComponent("large_file.txt")
        
        // 使用缓冲写入
        if let outputStream = OutputStream(url: filePath, append: false) {
            outputStream.open()
            defer { outputStream.close() }
            
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            
            // 模拟写入大量数据
            for i in 0..<1000 {
                let data = "Line \(i)\n".data(using: .utf8)!
                _ = data.withUnsafeBytes { ptr in
                    outputStream.write(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
                }
            }
        }
        
        // 使用缓冲读取
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
    }
    
    // MARK: - 文件缓存示例
    static func fileCacheExample() {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100 // 最多缓存100个文件
        cache.totalCostLimit = 50 * 1024 * 1024 // 最大缓存50MB
        
        func readFileWithCache(path: String) -> Data? {
            let key = path as NSString
            
            // 检查缓存
            if let cachedData = cache.object(forKey: key) {
                return cachedData as Data
            }
            
            // 从磁盘读取
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                cache.setObject(data as NSData, forKey: key)
                return data
            } catch {
                print("读取文件失败: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - 内存映射文件示例
    static func memoryMappedFileExample() {
        let fileManager = FileManager.default
        let documentPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentPath.appendingPathComponent("mmap_example.dat")
        
        // 创建一个大文件用于演示
        let fileSize = 100 * 1024 * 1024 // 100MB
        if !fileManager.fileExists(atPath: filePath.path) {
            fileManager.createFile(atPath: filePath.path, contents: Data(count: fileSize), attributes: nil)
        }
        
        do {
            let fileHandle = try FileHandle(forUpdating: filePath)
            defer { fileHandle.closeFile() }
            
            // 内存映射文件
            guard let data = fileHandle.map(offset: 0, size: fileSize) else {
                print("内存映射失败")
                return
            }
            
            // 通过内存映射访问文件
            data.withUnsafeMutableBytes { ptr in
                let buffer = ptr.bindMemory(to: UInt8.self)
                // 写入数据
                buffer[0] = 42
                // 读取数据
                let value = buffer[0]
                print("读取的值: \(value)")
            }
        } catch {
            print("文件操作失败: \(error)")
        }
    }
}