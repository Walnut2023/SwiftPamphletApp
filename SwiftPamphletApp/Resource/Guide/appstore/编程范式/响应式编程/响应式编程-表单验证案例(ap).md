# 响应式编程表单验证案例

## 简介

表单验证是响应式编程的典型应用场景之一。通过响应式编程，我们可以实现实时的表单验证，提供即时的用户反馈，提升用户体验。

## 基础示例

### 1. 登录表单
```swift
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isEmailValid = false
    @Published var isPasswordValid = false
    @Published var canSubmit = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 验证邮箱
        $email
            .map { email -> Bool in
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: email)
            }
            .assign(to: &$isEmailValid)
        
        // 验证密码
        $password
            .map { $0.count >= 6 }
            .assign(to: &$isPasswordValid)
        
        // 组合验证
        Publishers.CombineLatest($isEmailValid, $isPasswordValid)
            .map { $0 && $1 }
            .assign(to: &$canSubmit)
    }
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        Form {
            Section {
                TextField("邮箱", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                    Text("请输入有效的邮箱地址")
                        .foregroundColor(.red)
                }
                
                SecureField("密码", text: $viewModel.password)
                if !viewModel.password.isEmpty && !viewModel.isPasswordValid {
                    Text("密码至少需要6个字符")
                        .foregroundColor(.red)
                }
            }
            
            Button("登录") {
                // 处理登录逻辑
            }
            .disabled(!viewModel.canSubmit)
        }
    }
}
```

### 2. 注册表单
```swift
class RegistrationViewModel: ObservableObject {
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    
    @Published var isUsernameValid = false
    @Published var isEmailValid = false
    @Published var isPasswordValid = false
    @Published var doPasswordsMatch = false
    @Published var canSubmit = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 用户名验证
        $username
            .map { $0.count >= 3 }
            .assign(to: &$isUsernameValid)
        
        // 邮箱验证
        $email
            .map { email -> Bool in
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: email)
            }
            .assign(to: &$isEmailValid)
        
        // 密码验证
        $password
            .map { password -> Bool in
                // 至少包含一个大写字母、一个小写字母和一个数字
                let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d).{8,}$"
                let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
                return passwordPredicate.evaluate(with: password)
            }
            .assign(to: &$isPasswordValid)
        
        // 确认密码匹配
        Publishers.CombineLatest($password, $confirmPassword)
            .map { $0 == $1 }
            .assign(to: &$doPasswordsMatch)
        
        // 整体表单验证
        Publishers.CombineLatest4(
            $isUsernameValid,
            $isEmailValid,
            $isPasswordValid,
            $doPasswordsMatch
        )
        .map { $0 && $1 && $2 && $3 }
        .assign(to: &$canSubmit)
    }
}
```

## 高级示例

### 1. 防抖动验证
```swift
class DebouncedFormViewModel: ObservableObject {
    @Published var username = ""
    @Published var isUsernameAvailable = false
    @Published var isChecking = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 用户名可用性检查
        $username
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .filter { !$0.isEmpty }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isChecking = true
            })
            .flatMap { username -> AnyPublisher<Bool, Never> in
                // 模拟网络请求
                return Future<Bool, Never> { promise in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        promise(.success(username.count >= 3))
                    }
                }
                .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isChecking = false
            })
            .assign(to: &$isUsernameAvailable)
    }
}
```

### 2. 信用卡表单
```swift
class CreditCardViewModel: ObservableObject {
    @Published var cardNumber = ""
    @Published var expiryDate = ""
    @Published var cvv = ""
    
    @Published var formattedCardNumber = ""
    @Published var isCardValid = false
    @Published var isExpiryValid = false
    @Published var isCVVValid = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 格式化卡号
        $cardNumber
            .map { number -> String in
                let cleaned = number.filter { $0.isNumber }
                var formatted = ""
                for (index, char) in cleaned.enumerated() {
                    if index > 0 && index % 4 == 0 {
                        formatted += " "
                    }
                    formatted.append(char)
                }
                return String(formatted.prefix(19))
            }
            .assign(to: &$formattedCardNumber)
        
        // 验证卡号
        $cardNumber
            .map { $0.filter { $0.isNumber }.count == 16 }
            .assign(to: &$isCardValid)
        
        // 验证有效期
        $expiryDate
            .map { expiry -> Bool in
                let components = expiry.split(separator: "/")
                guard components.count == 2,
                      let month = Int(components[0]),
                      let year = Int(components[1]),
                      month >= 1 && month <= 12 else {
                    return false
                }
                
                let currentYear = Calendar.current.component(.year, from: Date()) % 100
                let currentMonth = Calendar.current.component(.month, from: Date())
                
                return year > currentYear || (year == currentYear && month >= currentMonth)
            }
            .assign(to: &$isExpiryValid)
        
        // 验证CVV
        $cvv
            .map { $0.count == 3 && $0.allSatisfy { $0.isNumber } }
            .assign(to: &$isCVVValid)
    }
}
```

## 最佳实践

### 1. 错误处理
```swift
enum ValidationError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case passwordMismatch
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "请输入有效的邮箱地址"
        case .invalidPassword:
            return "密码必须包含大小写字母和数字"
        case .passwordMismatch:
            return "两次输入的密码不一致"
        }
    }
}

class ValidatedFormViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errors: [ValidationError] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest($email, $password)
            .map { email, password -> [ValidationError] in
                var errors: [ValidationError] = []
                
                if !self.isValidEmail(email) {
                    errors.append(.invalidEmail)
                }
                
                if !self.isValidPassword(password) {
                    errors.append(.invalidPassword)
                }
                
                return errors
            }
            .assign(to: &$errors)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
}
```

### 2. 性能优化
```swift
class OptimizedFormViewModel: ObservableObject {
    @Published var searchTerm = ""
    @Published var suggestions: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 优化搜索建议的性能
        $searchTerm
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .map { term -> AnyPublisher<[String], Never> in
                // 模拟API调用
                return Future { promise in
                    DispatchQueue.global().async {
                        let results = ["示例1", "示例2"].filter { $0.contains(term) }
                        promise(.success(results))
                    }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: &$suggestions)
    }
}
```

## 注意事项

1. **用户体验**
   - 提供即时反馈
   - 清晰的错误提示
   - 适当的输入限制

2. **性能考虑**
   - 使用防抖动避免频繁验证
   - 异步处理耗时操作

3. **安全性**
   - 敏感信息的处理
   - 输入数据的清理

## 总结

响应式编程在表单验证中的应用可以大大提升用户体验和代码可维护性。通过Combine框架，我们可以优雅地处理各种表单验证场景，实现实时反馈和数据同步。在实际开发中，需要注意性能优化和用户体验的平衡，同时确保表单验证的安全性和可靠性。