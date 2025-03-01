# Swift Concurrency 结合 Combine 实践

## 简介

Swift Concurrency 和 Combine 各自都是强大的异步编程工具。通过结合使用，我们可以充分利用两者的优势：Swift Concurrency 的简洁语法和结构化并发，以及 Combine 的响应式数据流处理能力。

## 基础集成

### 1. 将 async/await 转换为 Publisher

```swift
class AsyncPublisher {
    static func makePublisher<T>(
        _ asyncOperation: @escaping () async throws -> T
    ) -> AnyPublisher<T, Error> {
        Deferred {
            Future { promise in
                Task {
                    do {
                        let result = try await asyncOperation()
                        promise(.success(result))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
}

// 使用示例
func fetchUserData(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

let publisher = AsyncPublisher.makePublisher {
    try await fetchUserData(id: 1)
}

publisher
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { user in
            print("User: \(user)")
        }
    )
    .store(in: &cancellables)
```

### 2. 将 Publisher 转换为 async/await

```swift
extension Publisher {
    func asyncValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var values = [Output]()
            
            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        continuation.resume(returning: values[0])
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    values.append(value)
                }
            )
        }
    }
}

// 使用示例
let dataPublisher = URLSession.shared.dataTaskPublisher(for: url)
    .map(\.data)
    .decode(type: User.self, decoder: JSONDecoder())

Task {
    do {
        let user = try await dataPublisher.asyncValue()
        print("Received user: \(user)")
    } catch {
        print("Error: \(error)")
    }
}
```

## 实际应用场景

### 1. 网络请求与缓存

```swift
class NetworkCache {
    static let shared = NetworkCache()
    private let cache = NSCache<NSString, AnyObject>()
    
    func fetchData<T: Codable>(
        from url: URL,
        cacheKey: String
    ) -> AnyPublisher<T, Error> {
        if let cached = cache.object(forKey: cacheKey as NSString) as? T {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return AsyncPublisher.makePublisher {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            self.cache.setObject(decoded as AnyObject, forKey: cacheKey as NSString)
            return decoded
        }
    }
}
```

### 2. UI 更新与状态管理

```swift
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    func loadItems() {
        isLoading = true
        
        let publisher = AsyncPublisher.makePublisher {
            try await fetchItems()
        }
        
        publisher
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            })
            .catch { error -> AnyPublisher<[Item], Never> in
                print("Error: \(error)")
                return Just([])
                    .eraseToAnyPublisher()
            }
            .assign(to: &$items)
    }
    
    private func fetchItems() async throws -> [Item] {
        let url = URL(string: "https://api.example.com/items")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Item].self, from: data)
    }
}
```

### 3. 并发操作与数据流处理

```swift
class DataProcessor {
    static func processData<T: Codable>(
        urls: [URL]
    ) -> AnyPublisher<[T], Error> {
        AsyncPublisher.makePublisher {
            try await withThrowingTaskGroup(of: T.self) { group in
                for url in urls {
                    group.addTask {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return try JSONDecoder().decode(T.self, from: data)
                    }
                }
                
                var results = [T]()
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
    }
}

// 使用示例
let urls = [
    URL(string: "https://api.example.com/data1")!,
    URL(string: "https://api.example.com/data2")!
]

DataProcessor.processData(urls: urls)
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { items in
            print("Received items: \(items)")
        }
    )
    .store(in: &cancellables)
```

## 性能优化

1. **内存管理**
   - 适时取消订阅
   - 使用 weak self 避免循环引用
   - 合理设置缓存大小

2. **并发控制**
   - 使用 TaskGroup 管理并发任务
   - 设置合适的任务优先级
   - 避免过度并发

3. **错误处理**
   - 实现优雅的错误恢复机制
   - 提供合适的默认值
   - 记录错误日志

## 最佳实践

1. **架构设计**
   - 清晰分离异步和响应式代码
   - 使用适当的抽象层
   - 保持代码可测试性

2. **代码组织**
   - 模块化设计
   - 统一错误处理
   - 文档注释

3. **调试技巧**
   - 使用 print 或自定义 Publisher 记录数据流
   - 合理使用断点
   - 监控内存和性能

## 总结

Swift Concurrency 和 Combine 的结合使用为异步编程提供了更强大和灵活的解决方案。通过合理运用两者的特性，我们可以编写出更简洁、可维护的代码，同时保持良好的性能和用户体验。在实际开发中，需要根据具体场景选择合适的方案，并注意遵循最佳实践。