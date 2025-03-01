# 函数式编程在实际项目中的应用

函数式编程不仅仅是一个理论概念，在实际项目中也有着广泛的应用。本文将通过实际的项目案例，展示函数式编程如何提高代码质量和开发效率。

## 项目案例一：数据处理管道

在一个电商应用中，我们经常需要对商品数据进行一系列处理：

```swift
// 定义数据处理函数
struct Product {
    let name: String
    let price: Double
    let category: String
    let stock: Int
}

// 价格处理函数
func applyDiscount(_ discount: Double) -> (Product) -> Product {
    return { product in
        Product(name: product.name,
               price: product.price * (1 - discount),
               category: product.category,
               stock: product.stock)
    }
}

// 库存检查函数
func checkStock(_ minimumStock: Int) -> (Product) -> Bool {
    return { product in product.stock >= minimumStock }
}

// 分类过滤函数
func filterByCategory(_ category: String) -> (Product) -> Bool {
    return { product in product.category == category }
}

// 使用函数组合处理商品数据
let products = [
    Product(name: "iPhone", price: 999.0, category: "Electronics", stock: 10),
    Product(name: "MacBook", price: 1299.0, category: "Electronics", stock: 5),
    Product(name: "Headphones", price: 299.0, category: "Accessories", stock: 15)
]

// 处理流程
let processProducts = products
    .filter(filterByCategory("Electronics"))
    .filter(checkStock(5))
    .map(applyDiscount(0.1))
```

## 项目案例二：网络请求处理

在处理网络请求时，函数式编程可以帮助我们构建清晰的数据转换流程：

```swift
import Combine

class NetworkService {
    // 网络请求函数
    func fetchData<T: Decodable>(_ url: URL) -> AnyPublisher<T, Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // 数据转换函数
    func transform<T, U>(_ data: T, _ transformer: @escaping (T) -> U) -> U {
        transformer(data)
    }
    
    // 错误处理函数
    func handleError<T>(_ error: Error) -> AnyPublisher<T, Never> {
        Just(error)
            .handleEvents(receiveOutput: { error in
                print("Error: \(error)")
            })
            .flatMap { _ in Empty<T, Never>() }
            .eraseToAnyPublisher()
    }
}

// 使用示例
class ProductViewModel {
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService()
    
    func fetchProducts() {
        let url = URL(string: "https://api.example.com/products")!
        
        networkService.fetchData(url)
            .map { (products: [Product]) in
                products.filter { $0.price > 0 }
            }
            .map { products in
                products.sorted { $0.price < $1.price }
            }
            .catch { [weak self] error in
                self?.networkService.handleError(error) ?? Empty().eraseToAnyPublisher()
            }
            .sink { completion in
                print("Completed with: \(completion)")
            } receiveValue: { products in
                print("Received products: \(products)")
            }
            .store(in: &cancellables)
    }
}
```

## 项目案例三：用户输入处理

在处理用户输入时，函数式编程可以帮助我们构建清晰的验证流程：

```swift
class FormValidator {
    // 验证函数类型
    typealias ValidationFunction = (String) -> ValidationResult
    
    enum ValidationResult {
        case success
        case failure(String)
    }
    
    // 验证规则
    static func validateEmail(_ email: String) -> ValidationResult {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
            ? .success
            : .failure("Invalid email format")
    }
    
    static func validatePassword(_ password: String) -> ValidationResult {
        return password.count >= 8
            ? .success
            : .failure("Password must be at least 8 characters")
    }
    
    // 组合验证函数
    static func combine(_ validations: [ValidationFunction]) -> ValidationFunction {
        return { input in
            for validation in validations {
                if case .failure(let message) = validation(input) {
                    return .failure(message)
                }
            }
            return .success
        }
    }
}

// 使用示例
class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var emailError: String? = nil
    @Published var passwordError: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听邮箱输入
        $email
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { email in
                FormValidator.validateEmail(email)
            }
            .sink { [weak self] result in
                if case .failure(let message) = result {
                    self?.emailError = message
                } else {
                    self?.emailError = nil
                }
            }
            .store(in: &cancellables)
        
        // 监听密码输入
        $password
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { password in
                FormValidator.validatePassword(password)
            }
            .sink { [weak self] result in
                if case .failure(let message) = result {
                    self?.passwordError = message
                } else {
                    self?.passwordError = nil
                }
            }
            .store(in: &cancellables)
    }
}
```

## 最佳实践建议

1. **适度使用**
   - 不要强行使用函数式编程
   - 在数据转换、验证等场景优先考虑
   - 保持代码可读性

2. **性能考虑**
   - 避免过长的函数链
   - 注意内存使用
   - 适当使用惰性计算

3. **错误处理**
   - 使用 Result 类型处理错误
   - 构建清晰的错误处理流程
   - 保持错误信息的可追踪性

4. **测试友好**
   - 纯函数易于测试
   - 使用依赖注入
   - 编写单元测试

## 总结

函数式编程在实际项目中的应用主要体现在：

- 数据处理流程的构建
- 异步操作的处理
- 用户输入的验证
- 状态管理
- 错误处理

通过合理使用函数式编程特性，我们可以：

- 提高代码的可维护性
- 减少状态管理的复杂度
- 提高代码的可测试性
- 构建清晰的数据流程

在实际开发中，建议根据项目需求和团队情况，合理选择函数式编程的应用场景，避免过度使用而导致代码难以理解和维护。