# SOLID 原则在 Swift 中的应用

## 引言
SOLID是面向对象编程中的五个基本设计原则的首字母缩写，它们帮助我们创建更易于维护和扩展的软件系统。在Swift开发中，这些原则同样适用且非常重要。

## 1. 单一职责原则 (Single Responsibility Principle, SRP)

### 原理
一个类应该只有一个引起它变化的原因。换句话说，一个类应该只负责一件事情。

### Swift示例
```swift
// 不好的示例 - 违反SRP
class UserManager {
    func authenticate(username: String, password: String) -> Bool {
        // 处理认证逻辑
        return true
    }
    
    func saveUserData(user: User) {
        // 保存用户数据
    }
    
    func formatUserProfile() -> String {
        // 格式化用户信息
        return ""
    }
}

// 好的示例 - 遵循SRP
class AuthenticationManager {
    func authenticate(username: String, password: String) -> Bool {
        // 只处理认证逻辑
        return true
    }
}

class UserStorage {
    func saveUserData(user: User) {
        // 只处理数据存储
    }
}

class UserProfileFormatter {
    func format(user: User) -> String {
        // 只处理格式化
        return ""
    }
}
```

### 实际应用场景
以下是一个更完整的示例，展示如何在用户认证、数据获取和UI更新的场景中应用单一职责原则：

```swift
// 1. 数据模型
struct User: Codable {
    let id: String
    let username: String
    let email: String
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var theme: String
    var notifications: Bool
}

// 2. 认证服务 - 只负责处理认证
protocol AuthenticationService {
    func login(username: String, password: String) async throws -> String // 返回token
    func logout() async
}

class APIAuthenticationService: AuthenticationService {
    func login(username: String, password: String) async throws -> String {
        // 实现登录逻辑，返回认证token
        return "auth_token"
    }
    
    func logout() async {
        // 实现登出逻辑
    }
}

// 3. 用户数据服务 - 只负责处理远程数据
protocol UserDataService {
    func fetchUserProfile(token: String) async throws -> User
    func updatePreferences(_ preferences: UserPreferences, token: String) async throws
}

class APIUserDataService: UserDataService {
    func fetchUserProfile(token: String) async throws -> User {
        // 实现获取用户数据的网络请求
        return User(id: "1", username: "test", email: "test@example.com",
                   preferences: UserPreferences(theme: "light", notifications: true))
    }
    
    func updatePreferences(_ preferences: UserPreferences, token: String) async throws {
        // 实现更新用户偏好的网络请求
    }
}

// 4. 本地存储服务 - 只负责处理本地数据持久化
protocol UserStorageService {
    func saveUser(_ user: User) throws
    func getUser() throws -> User?
    func clearUser() throws
}

class UserDefaultsStorageService: UserStorageService {
    private let userKey = "current_user"
    
    func saveUser(_ user: User) throws {
        let data = try JSONEncoder().encode(user)
        UserDefaults.standard.set(data, forKey: userKey)
    }
    
    func getUser() throws -> User? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    func clearUser() throws {
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}

// 5. 视图模型 - 协调各个服务并更新UI状态
@MainActor
class UserProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let authService: AuthenticationService
    private let dataService: UserDataService
    private let storageService: UserStorageService
    
    init(authService: AuthenticationService = APIAuthenticationService(),
         dataService: UserDataService = APIUserDataService(),
         storageService: UserStorageService = UserDefaultsStorageService()) {
        self.authService = authService
        self.dataService = dataService
        self.storageService = storageService
    }
    
    func login(username: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.login(username: username, password: password)
            let user = try await dataService.fetchUserProfile(token: token)
            try storageService.saveUser(user)
            self.user = user
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func updatePreferences(_ preferences: UserPreferences) async {
        guard let user = user else { return }
        
        do {
            try await dataService.updatePreferences(preferences, token: "auth_token")
            var updatedUser = user
            updatedUser.preferences = preferences
            try storageService.saveUser(updatedUser)
            self.user = updatedUser
        } catch {
            self.error = error
        }
    }
}

// 6. 视图 - 只负责UI的展示和用户交互
struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if let user = viewModel.user {
                VStack(alignment: .leading, spacing: 10) {
                    Text("用户名: \(user.username)")
                    Text("邮箱: \(user.email)")
                    Toggle("通知", isOn: Binding(
                        get: { user.preferences.notifications },
                        set: { newValue in
                            var newPreferences = user.preferences
                            newPreferences.notifications = newValue
                            Task {
                                await viewModel.updatePreferences(newPreferences)
                            }
                        }
                    ))
                }
                .padding()
            } else {
                VStack {
                    TextField("用户名", text: $username)
                    SecureField("密码", text: $password)
                    Button("登录") {
                        Task {
                            await viewModel.login(username: username, password: password)
                        }
                    }
                }
                .padding()
            }
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { _ in viewModel.error = nil }
        )) {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
}
```

在这个完整的示例中，我们通过以下方式实现了单一职责原则：

1. **数据模型** (`User`, `UserPreferences`) - 只负责定义数据结构
2. **认证服务** (`AuthenticationService`) - 只负责处理用户认证
3. **数据服务** (`UserDataService`) - 只负责处理远程数据操作
4. **存储服务** (`UserStorageService`) - 只负责处理本地数据持久化
5. **视图模型** (`UserProfileViewModel`) - 负责协调各个服务并维护UI状态
6. **视图** (`UserProfileView`) - 只负责UI的展示和用户交互

每个组件都有其明确的单一职责，通过协议定义接口，使得各个组件之间解耦，便于测试和维护。视图模型作为协调者，将各个服务组合起来完成完整的业务流程。

## 2. 开放封闭原则 (Open/Closed Principle, OCP)

### 原理
软件实体（类、模块、函数等）应该对扩展开放，对修改关闭。

### Swift示例
```swift
// 使用协议和扩展实现OCP
protocol Shape {
    func area() -> Double
}

class Rectangle: Shape {
    let width: Double
    let height: Double
    
    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    func area() -> Double {
        return width * height
    }
}

class Circle: Shape {
    let radius: Double
    
    init(radius: Double) {
        self.radius = radius
    }
    
    func area() -> Double {
        return Double.pi * radius * radius
    }
}

class AreaCalculator {
    func totalArea(shapes: [Shape]) -> Double {
        return shapes.reduce(0) { $0 + $1.area() }
    }
}
```

## 3. 里氏替换原则 (Liskov Substitution Principle, LSP)

### 原理
子类型必须能够替换其基类型。也就是说，程序中的对象应该可以在不改变程序正确性的前提下被它的子类所替换。

### Swift示例
```swift
protocol Bird {
    func move()
}

class FlyingBird: Bird {
    func move() {
        print("Flying in the sky")
    }
}

class Penguin: Bird {
    func move() {
        print("Walking and swimming")
    }
}

func moveAllBirds(_ birds: [Bird]) {
    birds.forEach { $0.move() }
}
```

## 4. 接口隔离原则 (Interface Segregation Principle, ISP)

### 原理
客户端不应该被强迫依赖于它们不使用的方法。

### Swift示例
```swift
// 不好的示例 - 违反ISP
protocol Worker {
    func work()
    func eat()
    func sleep()
}

// 好的示例 - 遵循ISP
protocol Workable {
    func work()
}

protocol Eatable {
    func eat()
}

protocol Sleepable {
    func sleep()
}

class Human: Workable, Eatable, Sleepable {
    func work() { }
    func eat() { }
    func sleep() { }
}

class Robot: Workable {
    func work() { }
    // 机器人不需要实现eat和sleep
}
```

## 5. 依赖倒置原则 (Dependency Inversion Principle, DIP)

### 原理
高层模块不应该依赖于低层模块，两者都应该依赖于抽象。抽象不应该依赖于细节，细节应该依赖于抽象。

### Swift示例
```swift
// 定义抽象层
protocol DataSource {
    func fetchData() async throws -> [String]
}

protocol DataProcessor {
    func process(_ data: [String]) -> [String]
}

// 实现具体细节
class NetworkDataSource: DataSource {
    func fetchData() async throws -> [String] {
        // 实现网络数据获取
        return ["data1", "data2"]
    }
}

class FilterProcessor: DataProcessor {
    func process(_ data: [String]) -> [String] {
        // 实现数据过滤
        return data.filter { !$0.isEmpty }
    }
}

// 高层模块
class DataManager {
    private let dataSource: DataSource
    private let processor: DataProcessor
    
    init(dataSource: DataSource, processor: DataProcessor) {
        self.dataSource = dataSource
        self.processor = processor
    }
    
    func getData() async throws -> [String] {
        let rawData = try await dataSource.fetchData()
        return processor.process(rawData)
    }
}
```

## 综合案例：电子书阅读器应用

这个综合案例展示了如何使用SwiftUI、Combine、Swift Concurrency和SwiftData构建一个遵循SOLID原则的电子书阅读器应用。

```swift
// 1. 数据模型 - 使用SwiftData
@Model
class Book {
    var id: String
    var title: String
    var author: String
    var content: String
    var lastReadPosition: Int
    
    init(id: String, title: String, author: String, content: String) {
        self.id = id
        self.title = title
        self.author = author
        self.content = content
        self.lastReadPosition = 0
    }
}

// 2. 仓储层 - 遵循依赖倒置原则
protocol BookRepository {
    func fetchBooks() async throws -> [Book]
    func saveBook(_ book: Book) async throws
    func updateReadingProgress(bookId: String, position: Int) async throws
}

class SwiftDataBookRepository: BookRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchBooks() async throws -> [Book] {
        let descriptor = FetchDescriptor<Book>()
        return try modelContext.fetch(descriptor)
    }
    
    func saveBook(_ book: Book) async throws {
        modelContext.insert(book)
        try modelContext.save()
    }
    
    func updateReadingProgress(bookId: String, position: Int) async throws {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate<Book> { book in
            book.id == bookId
        })
        if let book = try modelContext.fetch(descriptor).first {
            book.lastReadPosition = position
            try modelContext.save()
        }
    }
}

// 3. 网络服务 - 遵循单一职责原则
protocol BookService {
    func downloadBook(id: String) async throws -> Book
}

class NetworkBookService: BookService {
    func downloadBook(id: String) async throws -> Book {
        // 实现网络下载逻辑
        return Book(id: id, title: "Sample Book", author: "Author", content: "Content")
    }
}

// 4. 视图模型 - 使用Combine处理数据流
@MainActor
class BookLibraryViewModel: ObservableObject {
    @Published private(set) var books: [Book] = []
    private let repository: BookRepository
    private let bookService: BookService
    
    init(repository: BookRepository, bookService: BookService) {
        self.repository = repository
        self.bookService = bookService
    }
    
    func loadBooks() async {
        do {
            books = try await repository.fetchBooks()
        } catch {
            print("Error loading books: \(error)")
        }
    }
    
    func downloadBook(id: String) async {
        do {
            let book = try await bookService.downloadBook(id: id)
            try await repository.saveBook(book)
            await loadBooks()
        } catch {
            print("Error downloading book: \(error)")
        }
    }
}

// 5. 视图层 - 使用SwiftUI
struct BookLibraryView: View {
    @StateObject private var viewModel: BookLibraryViewModel
    
    init(viewModel: BookLibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            List(viewModel.books) { book in
                NavigationLink(destination: BookReaderView(book: book)) {
                    BookRowView(book: book)
                }
            }
            .navigationTitle("我的图书馆")
            .task {
                await viewModel.loadBooks()
            }
        }
    }
}

struct BookReaderView: View {
    let book: Book
    @State private var currentPosition: Int
    
    init(book: Book) {
        self.book = book
        _currentPosition = State(initialValue: book.lastReadPosition)
    }
    
    var body: some View {
        ScrollView {
            Text(book.content)
                .padding()
        }
        .navigationTitle(book.title)
    }
}

struct BookRowView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(book.title)
                .font(.headline)
            Text(book.author)
                .font(.subheadline)
        }
    }
}
```

### 综合案例中的SOLID原则应用

1. **单一职责原则 (SRP)**
   - `BookRepository` 只负责数据持久化
   - `BookService` 只负责网络请求
   - 每个View组件都有其单一的展示职责

2. **开放封闭原则 (OCP)**
   - 通过协议定义接口，允许添加新的实现而无需修改现有代码
   - 视图组件可以轻松扩展新的功能

3. **里氏替换原则 (LSP)**
   - `SwiftDataBookRepository` 可以被任何遵循 `BookRepository` 协议的实现替换
   - 所有的依赖注入都基于协议而非具体实现

4. **接口隔离原则 (ISP)**
   - 协议定义都很精简，只包含必要的方法
   - 视图组件的职责划分清晰

5. **依赖倒置原则 (DIP)**
   - 高层模块 (`BookLibraryViewModel`) 依赖于抽象 (`BookRepository`, `BookService`)
   - 通过依赖注入实现了模块间的解耦

### 现代Swift特性的应用

1. **SwiftUI**
   - 使用声明式UI构建用户界面
   - 视图状态管理清晰

2. **Combine**
   - 使用 `@Published` 进行响应式数据流处理
   - 视图模型中的状态更新自动触发UI更新

3. **Swift Concurrency**
   - 使用 `async/await` 处理异步操作
   - 通过 `@MainActor` 确保UI更新在主线程执行

4. **SwiftData**
   - 使用 `@Model` 定义数据模型
   - 通过 `ModelContext` 进行数据持久化

这个综合案例展示了如何在现代Swift应用开发中应用SOLID原则，同时充分利用Swift的最新特性构建一个结构清晰、易于维护的应用。通过遵循这些原则，我们的代码更容易测试、扩展和维护。