# 响应式编程与MVVM结合

## 简介

MVVM (Model-View-ViewModel) 架构模式与响应式编程天然契合，通过响应式编程可以优雅地实现视图和数据的双向绑定。本文将介绍如何在MVVM架构中应用响应式编程。

## 基础架构

### 1. 基本组件
```swift
// Model
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// ViewModel
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUser(id: Int) {
        isLoading = true
        
        let url = URL(string: "https://api.example.com/users/\(id)")!
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] user in
                    self?.user = user
                }
            )
            .store(in: &cancellables)
    }
}

// View
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                VStack {
                    Text(user.name)
                    Text(user.email)
                }
            } else if let error = viewModel.error {
                Text("错误: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            viewModel.fetchUser(id: 1)
        }
    }
}
```

## 数据绑定

### 1. 双向绑定
```swift
class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var bio = ""
    @Published var isSaving = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // 输入验证
    var isValid: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($name, $bio)
            .map { name, bio in
                return !name.isEmpty && !bio.isEmpty
            }
            .eraseToAnyPublisher()
    }
    
    func save() {
        isSaving = true
        // 保存逻辑
    }
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var canSave = false
    
    var body: some View {
        Form {
            TextField("姓名", text: $viewModel.name)
            TextEditor(text: $viewModel.bio)
            
            Button("保存") {
                viewModel.save()
            }
            .disabled(!canSave)
        }
        .onReceive(viewModel.isValid) { isValid in
            canSave = isValid
        }
    }
}
```

### 2. 列表绑定
```swift
class TodoListViewModel: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var newTodoTitle = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 自动保存更改
        $todos
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveTodos()
            }
            .store(in: &cancellables)
    }
    
    func addTodo() {
        guard !newTodoTitle.isEmpty else { return }
        let todo = Todo(title: newTodoTitle, isCompleted: false)
        todos.append(todo)
        newTodoTitle = ""
    }
    
    private func saveTodos() {
        // 保存到本地存储
    }
}
```

## 状态管理

### 1. 应用状态
```swift
class AppState: ObservableObject {
    @Published var user: User?
    @Published var settings: Settings
    @Published var currentTheme: Theme
    
    init() {
        self.settings = Settings()
        self.currentTheme = .light
        loadUser()
    }
    
    private func loadUser() {
        // 加载用户信息
    }
}

class MainViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        
        // 监听用户状态变化
        appState.$user
            .sink { [weak self] user in
                if user == nil {
                    self?.navigationPath.append("login")
                }
            }
            .store(in: &cancellables)
    }
}
```

### 2. 模块状态
```swift
class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isAuthenticated = false
    
    private let authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthenticationService) {
        self.authService = authService
        
        // 监听认证状态
        authService.authenticationPublisher
            .assign(to: &$isAuthenticated)
    }
    
    func login() {
        authService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("登录失败: \(error)")
                    }
                },
                receiveValue: { [weak self] success in
                    self?.isAuthenticated = success
                }
            )
            .store(in: &cancellables)
    }
}
```

## 依赖注入

### 1. 服务注入
```swift
protocol UserService {
    func fetchUser(id: Int) -> AnyPublisher<User, Error>
}

class UserViewModel: ObservableObject {
    private let userService: UserService
    private var cancellables = Set<AnyCancellable>()
    
    @Published var user: User?
    
    init(userService: UserService) {
        self.userService = userService
    }
    
    func loadUser(id: Int) {
        userService.fetchUser(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] user in
                    self?.user = user
                }
            )
            .store(in: &cancellables)
    }
}
```

## 测试

### 1. ViewModel测试
```swift
class MockUserService: UserService {
    var mockUser: User?
    var mockError: Error?
    
    func fetchUser(id: Int) -> AnyPublisher<User, Error> {
        if let error = mockError {
            return Fail(error: error).eraseToAnyPublisher()
        }
        if let user = mockUser {
            return Just(user)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        return Empty().eraseToAnyPublisher()
    }
}

class UserViewModelTests: XCTestCase {
    var viewModel: UserViewModel!
    var mockService: MockUserService!
    
    override func setUp() {
        mockService = MockUserService()
        viewModel = UserViewModel(userService: mockService)
    }
    
    func testLoadUserSuccess() {
        let expectation = XCTestExpectation(description: "Load user")
        let mockUser = User(id: 1, name: "Test", email: "test@example.com")
        mockService.mockUser = mockUser
        
        viewModel.$user
            .dropFirst()
            .sink { user in
                XCTAssertEqual(user?.id, mockUser.id)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.loadUser(id: 1)
        wait(for: [expectation], timeout: 1.0)
    }
}
```

## 最佳实践

1. **职责分离**
   - ViewModel负责业务逻辑
   - View只负责UI展示
   - Model保持简单的数据结构

2. **状态管理**
   - 使用@Published属性追踪状态变化
   - 合理划分状态范围
   - 避免状态重复

3. **内存管理**
   - 正确使用weak self
   - 及时取消订阅
   - 避免循环引用

## 注意事项

1. **架构设计**
   - 保持ViewModel的独立性
   - 避免View直接操作Model
   - 合理使用依赖注入

2. **性能优化**
   - 避免过度使用Publisher
   - 合理使用防抖和节流
   - 注意内存占用

3. **测试策略**
   - 编写单元测试
   - 使用mock对象
   - 测试边界条件

## 总结

响应式编程与MVVM的结合为iOS应用开发提供了一种强大的架构方案。通过Combine框架，我们可以优雅地处理数据流、状态管理和UI更新。在实际开发中，需要注意架构的清晰性、代码的可测试性，以及性能优化等方面的考虑。合理运用响应式编程和MVVM模式，可以帮助我们构建出更加可维护、可测试的应用程序。