# 声明式编程项目重构指南

## 重构目标

将现有的命令式代码重构为声明式代码，提高代码的可维护性和可读性，同时保持应用的功能和性能。

## 重构策略

### 1. 渐进式重构
- 分模块进行重构
- 保持新旧代码的兼容性
- 增量式替换，避免大规模重写

### 2. 优先级划分
1. UI层：优先使用SwiftUI重构
2. 数据流：引入Combine或Swift Concurrency
3. 状态管理：采用声明式状态管理
4. 业务逻辑：根据实际需求选择重构方式

## 实践案例

### 1. UIKit视图重构为SwiftUI

#### 原始代码（UIKit）
```swift
class ProfileViewController: UIViewController {
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let updateButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateProfile()
    }
    
    private func setupUI() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(nameLabel)
        view.addSubview(emailLabel)
        view.addSubview(updateButton)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            updateButton.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 20),
            updateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        updateButton.addTarget(self, action: #selector(updateProfile), for: .touchUpInside)
    }
    
    @objc private func updateProfile() {
        // 更新用户信息
    }
}
```

#### 重构后代码（SwiftUI）
```swift
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.name)
                .font(.headline)
            
            Text(viewModel.email)
                .font(.subheadline)
            
            Button("更新资料") {
                viewModel.updateProfile()
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    
    func updateProfile() {
        // 更新用户信息
    }
}
```

### 2. 网络请求重构

#### 原始代码（命令式）
```swift
class NetworkManager {
    func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: URL(string: "https://api.example.com")!) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data {
                completion(.success(data))
            }
        }.resume()
    }
}

// 使用方式
networkManager.fetchData { result in
    switch result {
    case .success(let data):
        // 处理数据
        break
    case .failure(let error):
        // 处理错误
        break
    }
}
```

#### 重构后代码（声明式）
```swift
actor NetworkManager {
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.example.com")!)
        return data
    }
}

// 使用方式
Task {
    do {
        let data = try await networkManager.fetchData()
        // 处理数据
    } catch {
        // 处理错误
    }
}
```

### 3. 状态管理重构

#### 原始代码（命令式）
```swift
class UserManager {
    static let shared = UserManager()
    
    private var user: User?
    private var observers: [(User?) -> Void] = []
    
    func setUser(_ user: User?) {
        self.user = user
        notifyObservers()
    }
    
    func addObserver(_ observer: @escaping (User?) -> Void) {
        observers.append(observer)
    }
    
    private func notifyObservers() {
        observers.forEach { $0(user) }
    }
}
```

#### 重构后代码（声明式）

```swift
@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published private(set) var user: User?
    
    func setUser(_ user: User?) {
        self.user = user
    }
}

// 使用方式
struct UserView: View {
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        if let user = userManager.user {
            UserProfileView(user: user)
        } else {
            LoginView()
        }
    }
}
```

## 重构注意事项

### 1. 性能优化
- 使用Instruments监控性能变化
- 注意内存使用和渲染性能
- 合理使用异步操作

### 2. 测试策略
- 保持现有测试用例
- 为新的声明式代码添加单元测试
- 进行UI测试和集成测试

### 3. 团队协作
- 制定统一的重构规范
- 进行代码评审
- 保持文档更新

## 重构工具

1. **代码分析工具**
   - SwiftLint
   - SonarQube
   - Xcode的重构工具

2. **测试工具**
   - XCTest
   - ViewInspector（SwiftUI测试）
   - Snapshot Testing

## 最佳实践

1. **代码组织**

```swift
// 将相关功能组织在一起
struct FeatureView: View {
    // 状态
    @StateObject private var viewModel = FeatureViewModel()
    
    // 视图组件
    var body: some View {
        content
    }
    
    // 提取子视图
    private var content: some View {
        VStack {
            header
            list
            footer
        }
    }
    
    private var header: some View {
        Text(viewModel.title)
    }
    
    private var list: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
        }
    }
    
    private var footer: some View {
        Button("加载更多") {
            viewModel.loadMore()
        }
    }
}
```

2. **状态管理**

```swift
// 使用专门的状态容器
class FeatureViewModel: ObservableObject {
    // 状态
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    // 意图
    func loadMore() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newItems = try await fetchItems()
            items.append(contentsOf: newItems)
        } catch {
            self.error = error
        }
    }
}
```

## 总结

重构到声明式编程是一个渐进的过程，需要在保持应用稳定性的同时，逐步改进代码质量。通过合理的重构策略、良好的工程实践和团队协作，我们可以成功地将命令式代码转换为更易维护、更具扩展性的声明式代码。在重构过程中，要注意平衡改进速度和代码质量，确保重构后的代码既满足业务需求，又具有良好的可维护性。
