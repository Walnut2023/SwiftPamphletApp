# 面向协议编程与测试友好性

面向协议编程（POP）不仅能提高代码的可维护性，还能显著提升代码的可测试性。本文将介绍如何利用协议来编写更易测试的代码。

## 协议与测试的关系

### 1. 依赖隔离

```swift
protocol DataFetching {
    func fetchData() async throws -> [String]
}

class MockDataFetcher: DataFetching {
    var mockData: [String] = []
    var shouldThrowError = false
    
    func fetchData() async throws -> [String] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1)
        }
        return mockData
    }
}

class ProductViewModel {
    private let dataFetcher: DataFetching
    
    init(dataFetcher: DataFetching) {
        self.dataFetcher = dataFetcher
    }
    
    func loadData() async throws -> [String] {
        try await dataFetcher.fetchData()
    }
}
```

### 2. 行为验证

```swift
protocol AnalyticsTracking {
    func trackEvent(_ name: String, parameters: [String: Any]?)
}

class MockAnalytics: AnalyticsTracking {
    var trackedEvents: [(name: String, parameters: [String: Any]?)] = []
    
    func trackEvent(_ name: String, parameters: [String: Any]?) {
        trackedEvents.append((name, parameters))
    }
}

class CheckoutViewModel {
    private let analytics: AnalyticsTracking
    
    init(analytics: AnalyticsTracking) {
        self.analytics = analytics
    }
    
    func completeCheckout() {
        analytics.trackEvent("checkout_completed", parameters: ["time": Date()])
    }
}
```

## 测试友好的设计模式

### 1. 状态验证

```swift
protocol StateValidating {
    var currentState: ViewState { get }
    func validate() -> Bool
}

enum ViewState {
    case initial
    case loading
    case loaded
    case error(Error)
}

class TestableViewModel: StateValidating {
    private(set) var currentState: ViewState = .initial
    
    func validate() -> Bool {
        // 验证状态转换是否正确
        return true
    }
}
```

### 2. 结果验证

```swift
protocol ResultValidating {
    associatedtype Output
    var lastResult: Output? { get }
    func validateResult(_ result: Output) -> Bool
}

class DataProcessor: ResultValidating {
    typealias Output = [String: Any]
    
    private(set) var lastResult: [String: Any]?
    
    func validateResult(_ result: [String: Any]) -> Bool {
        // 验证处理结果是否符合预期
        return true
    }
}
```

## 测试辅助工具

### 1. 测试容器

```swift
protocol TestContainer {
    associatedtype Dependencies
    var dependencies: Dependencies { get }
    func reset()
}

class TestAppContainer: TestContainer {
    struct Dependencies {
        var dataFetcher: DataFetching
        var analytics: AnalyticsTracking
    }
    
    var dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func reset() {
        // 重置测试环境
    }
}
```

### 2. 测试数据生成器

```swift
protocol TestDataGenerating {
    associatedtype Model
    func generateTestData() -> Model
    func generateMockData(count: Int) -> [Model]
}

struct UserTestDataGenerator: TestDataGenerating {
    struct User {
        let id: String
        let name: String
    }
    
    func generateTestData() -> User {
        User(id: UUID().uuidString, name: "Test User")
    }
    
    func generateMockData(count: Int) -> [User] {
        (0..<count).map { i in
            User(id: UUID().uuidString, name: "Test User \(i)")
        }
    }
}
```

## 最佳实践

1. **协议隔离原则**
   - 为不同的测试场景创建专门的协议
   - 避免在测试协议中包含不必要的方法

2. **可配置性**

```swift
protocol Configurable {
   associatedtype Configuration
   func configure(with configuration: Configuration)
}

extension Configurable {
   func withConfiguration(_ configuration: Configuration) -> Self {
       var copy = self
       copy.configure(with: configuration)
       return copy
   }
}
```

3. **错误处理**

```swift
protocol ErrorSimulating {
   func simulateError(_ error: Error)
   func simulateNetworkError()
   func simulateTimeoutError()
}

extension ErrorSimulating {
   func simulateNetworkError() {
       simulateError(NSError(domain: "Network", code: -1009))
   }
   
   func simulateTimeoutError() {
       simulateError(NSError(domain: "Network", code: -1001))
   }
}
```

## 测试示例

```swift
class ViewModelTests: XCTestCase {
    var sut: ProductViewModel!
    var mockFetcher: MockDataFetcher!
    
    override func setUp() {
        super.setUp()
        mockFetcher = MockDataFetcher()
        sut = ProductViewModel(dataFetcher: mockFetcher)
    }
    
    func testLoadDataSuccess() async throws {
        // 准备测试数据
        mockFetcher.mockData = ["item1", "item2"]
        
        // 执行测试
        let result = try await sut.loadData()
        
        // 验证结果
        XCTAssertEqual(result, ["item1", "item2"])
    }
    
    func testLoadDataFailure() async {
        // 配置mock抛出错误
        mockFetcher.shouldThrowError = true
        
        // 验证错误处理
        do {
            _ = try await sut.loadData()
            XCTFail("Expected error to be thrown")
        } catch {
            // 错误被正确处理
        }
    }
}
```

通过合理运用面向协议编程的原则，我们可以：

- 轻松创建测试替身（Mock、Stub、Spy）
- 隔离外部依赖
- 简化测试代码
- 提高测试覆盖率

在实际开发中，建议在设计之初就考虑测试需求，通过协议定义清晰的接口边界，为后续的测试工作打下良好基础。
