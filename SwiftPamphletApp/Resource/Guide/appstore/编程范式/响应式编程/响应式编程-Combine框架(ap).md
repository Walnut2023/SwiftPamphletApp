# Combine框架

## 简介

Combine是Apple在WWDC 2019推出的响应式编程框架，为Swift提供了声明式的数据处理方式。

## 核心组件

### 1. Publisher（发布者）
```swift
// 创建自定义Publisher
let publisher = Just(5)

// 使用CurrentValueSubject
let subject = CurrentValueSubject<Int, Never>(0)
subject.send(1) // 发送新值

// 使用PassthroughSubject
let passthroughSubject = PassthroughSubject<String, Never>()
passthroughSubject.send("Hello Combine")
```

### 2. Subscriber（订阅者）
```swift
// 基本订阅
let cancellable = publisher.sink { value in
    print("Received: \(value)")
}

// 自定义Subscriber
class CustomSubscriber: Subscriber {
    typealias Input = String
    typealias Failure = Never
    
    func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }
    
    func receive(_ input: String) -> Subscribers.Demand {
        print("Received: \(input)")
        return .none
    }
    
    func receive(completion: Subscribers.Completion<Never>) {
        print("Completed")
    }
}
```

### 3. Operator（操作符）
```swift
// 常用操作符示例
let numbers = [1, 2, 3, 4, 5]
    .publisher
    .map { $0 * 2 }      // 转换
    .filter { $0 > 5 }   // 过滤
    .collect()           // 收集
    .sink { values in
        print(values)    // [6, 8, 10]
    }
```

## 实际应用

### 1. 网络请求
```swift
// 封装网络请求
class NetworkService {
    func fetchData<T: Decodable>(_ url: URL) -> AnyPublisher<T, Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\?.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// 使用示例
let service = NetworkService()
var cancellables = Set<AnyCancellable>()

service.fetchData<User>(url)
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("请求完成")
        case .failure(let error):
            print("请求失败: \(error)")
        }
    }, receiveValue: { user in
        print("获取到用户: \(user)")
    })
    .store(in: &cancellables)
```

### 2. 表单验证
```swift
// 表单验证示例
class FormViewModel {
    @Published var email = ""
    @Published var password = ""
    @Published var isValid = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest($email, $password)
            .map { email, password in
                return email.contains("@") && password.count >= 6
            }
            .assign(to: &$isValid)
    }
}
```

### 3. 定时器
```swift
// 创建定时器
let timer = Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { date in
        print("当前时间: \(date)")
    }
```

## 高级特性

### 1. 错误处理
```swift
// 错误处理示例
publisher
    .tryMap { value -> Int in
        guard value > 0 else {
            throw ValidationError.invalidValue
        }
        return value
    }
    .catch { error -> AnyPublisher<Int, Never> in
        return Just(0).eraseToAnyPublisher()
    }
    .sink { value in
        print(value)
    }
```

### 2. 背压处理
```swift
// 背压控制
publisher
    .buffer(size: 10, prefetch: .byRequest, whenFull: .dropOldest)
    .sink { value in
        // 处理数据
    }
```

### 3. 调度器
```swift
// 线程调度
publisher
    .subscribe(on: DispatchQueue.global())
    .receive(on: DispatchQueue.main)
    .sink { value in
        // 在主线程更新UI
    }
```

## 最佳实践

### 1. 内存管理
```swift
// 使用AnyCancellable管理订阅
class ViewModel {
    private var cancellables = Set<AnyCancellable>()
    
    func subscribe() {
        publisher
            .sink { _ in }
            .store(in: &cancellables)
    }
}
```

### 2. 调试
```swift
// 调试操作符
publisher
    .print("Debug")
    .handleEvents(
        receiveSubscription: { _ in print("订阅开始") },
        receiveOutput: { value in print("收到值: \(value)") },
        receiveCompletion: { _ in print("订阅结束") }
    )
```

### 3. 性能优化
```swift
// 使用share()避免重复订阅
let sharedPublisher = publisher
    .share()
    .eraseToAnyPublisher()
```

## 注意事项

1. **版本兼容**
   - Combine需要iOS 13+
   - 考虑向后兼容方案

2. **内存管理**
   - 及时取消不需要的订阅
   - 避免循环引用

3. **调试建议**
   - 使用print和handleEvents跟踪数据流
   - Xcode调试器支持

## 总结

Combine作为Apple官方的响应式框架，提供了强大的数据处理能力。它与SwiftUI的完美集成使其成为现代iOS开发的重要工具。通过合理使用Combine的各种特性，我们可以构建出更加响应式、可维护的应用程序。在实际开发中，需要注意内存管理、错误处理等关键点，同时也要考虑版本兼容性问题。