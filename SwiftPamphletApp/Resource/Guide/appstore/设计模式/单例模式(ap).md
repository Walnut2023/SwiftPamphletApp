# Swift 单例模式

单例模式（Singleton Pattern）是一种常用的设计模式，它确保一个类只有一个实例，并提供一个全局访问点来访问该实例。单例模式在需要严格控制资源访问的场景中非常有用，例如数据库连接、文件管理器、网络管理器等。

## 单例模式的特点

- 确保类只有一个实例
- 提供对该实例的全局访问点
- 延迟初始化（通常在首次使用时创建）
- 线程安全（在多线程环境中保证只创建一个实例）

## Swift 中实现单例模式

### 传统实现方式

在 Swift 中，最简单的单例实现方式如下：

```swift
class Singleton {
    // 静态常量作为共享实例
    static let shared = Singleton()
    
    // 私有初始化方法，防止外部创建实例
    private init() {
        // 初始化代码
    }
    
    func doSomething() {
        print("单例方法被调用")
    }
}

// 使用单例
Singleton.shared.doSomething()
```

这种实现方式有以下特点：

1. 使用 `static let` 确保实例只被创建一次
2. 私有初始化方法 `private init()` 防止外部创建新实例
3. Swift 的静态常量是线程安全的，不需要额外的同步措施

### Objective-C 风格的实现（不推荐）

早期从 Objective-C 迁移过来的代码可能会使用以下方式：

```swift
class OldStyleSingleton {
    static let shared = OldStyleSingleton()
    
    class func sharedInstance() -> OldStyleSingleton {
        return shared
    }
    
    private init() {}
}

// 使用
OldStyleSingleton.sharedInstance().doSomething()
```

这种方式添加了一个不必要的静态方法，在 Swift 中是多余的。

### 带有配置选项的单例

有时我们需要在使用单例前进行一些配置：

```swift
class ConfigurableSingleton {
    static let shared = ConfigurableSingleton()
    
    private init() {}
    
    var configuration: String = "默认配置"
    
    func configure(with config: String) {
        configuration = config
    }
    
    func doSomething() {
        print("使用配置: \(configuration)")
    }
}

// 配置并使用
ConfigurableSingleton.shared.configure(with: "自定义配置")
ConfigurableSingleton.shared.doSomething()
```

### 线程安全的延迟初始化（旧方式）

在 Swift 1.2 之前，可能会看到以下实现方式：

```swift
class OldLazySingleton {
    class var sharedInstance: OldLazySingleton {
        struct Static {
            static var instance: OldLazySingleton? = nil
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            Static.instance = OldLazySingleton()
        }
        
        return Static.instance!
    }
    
    private init() {}
}
```

现代 Swift 不再需要这种复杂的实现，因为 `static let` 已经是线程安全的。

## 单例模式的最佳实践

### 何时使用单例

- 当一个类必须只有一个实例，而且必须从一个众所周知的访问点访问它
- 当这个唯一的实例需要通过子类化进行扩展，并且客户端代码能够使用扩展的实例而不需要修改代码

### 何时避免使用单例

- 当它仅仅是为了避免传递依赖
- 当你需要更好的测试隔离
- 当你需要更灵活的架构

### 依赖注入替代方案

在现代 Swift 开发中，依赖注入通常是比单例更好的选择：

```swift
protocol NetworkServiceType {
    func fetchData(completion: @escaping (Result<Data, Error>) -> Void)
}

class NetworkService: NetworkServiceType {
    func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
        // 实现网络请求
    }
}

class DataManager {
    let networkService: NetworkServiceType
    
    init(networkService: NetworkServiceType) {
        self.networkService = networkService
    }
    
    func loadData() {
        networkService.fetchData { result in
            // 处理结果
        }
    }
}

// 使用
let networkService = NetworkService()
let dataManager = DataManager(networkService: networkService)
dataManager.loadData()
```

## 著名开源项目中的单例应用

### Alamofire 中的 SessionManager

Alamofire 是 Swift 中最流行的网络请求库之一，它使用单例模式管理网络会话：

```swift
open class SessionManager {
    // 默认单例实例
    public static let `default`: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        
        return SessionManager(configuration: configuration)
    }()
    
    // 其他实现...
}

// 使用默认单例
Alamofire.request("https://api.example.com/data")
// 实际上是调用
// SessionManager.default.request(...)
```

Alamofire 的实现允许使用默认单例，同时也支持创建自定义的 SessionManager 实例，这提供了更大的灵活性。

### Kingfisher 中的 ImageDownloader

Kingfisher 是一个用于下载和缓存图片的库，它使用单例模式管理图片下载器：

```swift
public class ImageDownloader {
    // 共享单例
    public static let `default` = ImageDownloader(name: "default")
    
    // 允许创建自定义实例
    public init(name: String) {
        // 初始化代码
    }
    
    // 其他实现...
}

// 使用默认下载器
Kingfisher.ImageDownloader.default.downloadImage(with: url) { result in
    // 处理结果
}
```

### URLSession 中的 shared 实例

Apple 自己的 URLSession 也使用单例模式提供一个共享会话：

```swift
let task = URLSession.shared.dataTask(with: url) { data, response, error in
    // 处理响应
}
task.resume()
```

`URLSession.shared` 是一个预配置的会话单例，适用于基本的网络请求。同时，URLSession 也允许创建自定义配置的会话实例。

### UserDefaults 中的 standard 实例

UserDefaults 提供了一个标准单例来访问用户默认设置：

```swift
// 保存数据
UserDefaults.standard.set("value", forKey: "key")

// 读取数据
let value = UserDefaults.standard.string(forKey: "key")
```

### FileManager 中的 default 实例

FileManager 使用单例模式提供对文件系统的访问：

```swift
let fileManager = FileManager.default
let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
```

## 单例模式的演进

随着 Swift 的发展，单例模式的实现和使用也在演进：

1. **Swift 1.x**: 使用 `dispatch_once` 确保线程安全
2. **Swift 2.x+**: 使用 `static let` 实现线程安全的单例
3. **现代 Swift**: 更倾向于依赖注入而非单例，或者提供默认单例的同时允许创建自定义实例

## 结论

单例模式在 Swift 中实现简单且高效，特别是使用 `static let` 属性。然而，过度使用单例会导致紧耦合和测试困难。在现代 Swift 开发中，建议：

1. 只在确实需要全局唯一实例时使用单例
2. 考虑提供创建自定义实例的能力，如 Alamofire 和 Kingfisher 所做的那样
3. 对于大多数情况，优先考虑依赖注入
4. 使用协议和接口隔离，提高代码的可测试性

通过合理使用单例模式，可以在保持代码简洁的同时避免其潜在的缺点。