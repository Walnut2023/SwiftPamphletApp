# 面向协议编程与依赖注入

依赖注入是一种设计模式，它通过将依赖关系的创建和使用分离，来提高代码的可测试性、可维护性和灵活性。在Swift中，结合面向协议编程，我们可以实现更加优雅和灵活的依赖注入。

## 基本概念

依赖注入的核心思想是：一个类不应该负责创建它所依赖的对象，而应该通过外部注入这些依赖。主要有三种注入方式：

1. **构造器注入**
2. **属性注入**
3. **方法注入**

## 在Swift中的实现

### 1. 使用协议定义依赖

```swift
// 定义网络服务协议
protocol NetworkServiceProtocol {
    func fetchData<T: Decodable>(from url: URL) async throws -> T
}

// 定义数据存储协议
protocol StorageServiceProtocol {
    func save<T: Encodable>(_ item: T, forKey key: String) throws
    func load<T: Decodable>(forKey key: String) throws -> T
}

// 实现具体的网络服务
class NetworkService: NetworkServiceProtocol {
    func fetchData<T: Decodable>(from url: URL) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// 实现具体的存储服务
class StorageService: StorageServiceProtocol {
    func save<T: Encodable>(_ item: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(item)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    func load<T: Decodable>(forKey key: String) throws -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw NSError(domain: "StorageService", code: 404)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 2. 构造器注入

```swift
class UserViewModel {
    private let network: NetworkServiceProtocol
    private let storage: StorageServiceProtocol
    
    init(network: NetworkServiceProtocol, storage: StorageServiceProtocol) {
        self.network = network
        self.storage = storage
    }
    
    func fetchAndSaveUser(id: String) async throws {
        let user: User = try await network.fetchData(from: URL(string: "api/users/\(id)")!)
        try storage.save(user, forKey: "user_\(id)")
    }
}
```

### 3. 属性注入

```swift
class SettingsViewModel {
    var network: NetworkServiceProtocol!
    var storage: StorageServiceProtocol!
    
    func configure(network: NetworkServiceProtocol, storage: StorageServiceProtocol) {
        self.network = network
        self.storage = storage
    }
}
```

### 4. 方法注入

```swift
class DataProcessor {
    func processData<T: Decodable>(_ data: T, using storage: StorageServiceProtocol) throws {
        try storage.save(data, forKey: String(describing: T.self))
    }
}
```

## 依赖容器

在大型应用中，我们可以使用依赖容器来管理所有的依赖：

```swift
class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    lazy var networkService: NetworkServiceProtocol = NetworkService()
    lazy var storageService: StorageServiceProtocol = StorageService()
    
    func makeUserViewModel() -> UserViewModel {
        return UserViewModel(network: networkService, storage: storageService)
    }
}
```

## 使用Swinject实现依赖注入

Swinject是Swift的依赖注入框架，它提供了一种优雅的方式来管理依赖关系。以下是如何使用Swinject来实现依赖注入：

### 1. 基本设置

首先，通过Swift Package Manager添加Swinject依赖：

```swift
// Package.swift
.package(url: "https://github.com/Swinject/Swinject.git", from: "2.8.0")
```

### 2. 容器配置

```swift
let container = Container()

// 注册服务
container.register(NetworkServiceProtocol.self) { _ in
    NetworkService()
}

container.register(StorageServiceProtocol.self) { _ in
    StorageService()
}

// 注册视图模型
container.register(UserViewModel.self) { resolver in
    let network = resolver.resolve(NetworkServiceProtocol.self)!
    let storage = resolver.resolve(StorageServiceProtocol.self)!
    return UserViewModel(network: network, storage: storage)
}
```

### 3. 在SwiftUI中使用

```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    let container = Container()
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        setupDependencies()
        return true
    }
    
    private func setupDependencies() {
        container.register(NetworkServiceProtocol.self) { _ in NetworkService() }
        container.register(StorageServiceProtocol.self) { _ in StorageService() }
    }
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appDelegate.container.resolve(UserViewModel.self)!)
        }
    }
}
```

### 4. 高级用法

#### 命名注册

```swift
container.register(NetworkServiceProtocol.self, name: "production") { _ in
    ProductionNetworkService()
}

container.register(NetworkServiceProtocol.self, name: "mock") { _ in
    MockNetworkService()
}

// 解析特定实现
let productionService = container.resolve(NetworkServiceProtocol.self, name: "production")!
```

#### 单例注册

```swift
container.register(StorageServiceProtocol.self) { _ in
    StorageService()
}.inObjectScope(.container) // 使用单例模式
```

#### 循环依赖处理

```swift
container.register(ServiceA.self) { resolver in
    let serviceA = ServiceA()
    serviceA.serviceB = resolver.resolve(ServiceB.self)!
    return serviceA
}

container.register(ServiceB.self) { resolver in
    let serviceB = ServiceB()
    serviceB.serviceA = resolver.resolve(ServiceA.self)!
    return serviceB
}
```

### 5. 测试中的应用

```swift
class TestContainer {
    static func createContainer() -> Container {
        let container = Container()
        
        // 注册mock服务
        container.register(NetworkServiceProtocol.self) { _ in
            MockNetworkService()
        }
        
        container.register(StorageServiceProtocol.self) { _ in
            MockStorageService()
        }
        
        return container
    }
}

class ViewModelTests: XCTestCase {
    var container: Container!
    var viewModel: UserViewModel!
    
    override func setUp() {
        super.setUp()
        container = TestContainer.createContainer()
        viewModel = container.resolve(UserViewModel.self)!
    }
    
    func testFetchUser() async throws {
        // 测试代码
    }
}
```

### 6. 最佳实践

1. **模块化注册**
   - 将依赖注册按功能模块组织
   - 使用Assembly协议组织容器配置

```swift
class NetworkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(NetworkServiceProtocol.self) { _ in
            NetworkService()
        }
    }
}

class StorageAssembly: Assembly {
    func assemble(container: Container) {
        container.register(StorageServiceProtocol.self) { _ in
            StorageService()
        }
    }
}

// 使用Assembler
let assembler = Assembler([
    NetworkAssembly(),
    StorageAssembly()
])
```

2. **避免服务定位器反模式**
   - 不要在整个应用中传递Container实例
   - 在组合根（Composition Root）处解析依赖

3. **合理使用对象作用域**
   - `.transient`: 每次解析创建新实例
   - `.container`: 容器级别的单例
   - `.graph`: 对象图中的共享实例

4. **错误处理**
   - 使用可选绑定处理解析失败
   - 在开发环境使用强制解包便于发现问题

Swinject提供了一种强大而灵活的方式来实现依赖注入，它与Swift的类型系统完美配合，并且可以很好地集成到SwiftUI应用中。通过合理使用Swinject，我们可以构建出更加模块化、可测试和可维护的应用程序。

## 在测试中的应用

依赖注入使得单元测试变得更加容易：

```swift
// 模拟网络服务
class MockNetworkService: NetworkServiceProtocol {
    var mockData: Data?
    var error: Error?
    
    func fetchData<T: Decodable>(from url: URL) async throws -> T {
        if let error = error {
            throw error
        }
        guard let data = mockData else {
            throw NSError(domain: "MockNetworkService", code: 404)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// 测试用例
func testUserViewModel() async throws {
    let mockNetwork = MockNetworkService()
    let storage = StorageService()
    let viewModel = UserViewModel(network: mockNetwork, storage: storage)
    
    // 设置模拟数据
    let mockUser = User(id: "1", name: "Test")
    mockNetwork.mockData = try JSONEncoder().encode(mockUser)
    
    // 执行测试
    try await viewModel.fetchAndSaveUser(id: "1")
    
    // 验证结果
    let savedUser: User = try storage.load(forKey: "user_1")
    XCTAssertEqual(savedUser.id, mockUser.id)
}
```

## 最佳实践

1. **使用协议定义依赖**
   - 依赖应该基于抽象（协议）而不是具体实现
   - 协议应该保持简单和专注

2. **选择合适的注入方式**
   - 优先使用构造器注入
   - 属性注入适用于可选依赖
   - 方法注入适用于临时依赖

3. **依赖容器的使用**
   - 在应用程序的根层次管理依赖
   - 避免在业务逻辑中直接使用容器

4. **测试友好**
   - 确保所有依赖都可以被模拟
   - 使用协议使得测试替身更容易实现

通过结合面向协议编程和依赖注入，我们可以构建出更加灵活、可测试和可维护的Swift应用程序。这种方式不仅提高了代码的质量，还使得代码更容易适应需求的变化。在实际项目中，应该根据具体情况选择合适的注入方式，并确保依赖关系的清晰和可控。