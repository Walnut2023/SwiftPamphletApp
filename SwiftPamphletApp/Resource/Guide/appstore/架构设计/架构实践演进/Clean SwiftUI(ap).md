# Clean SwiftUI架构

## 架构概述

Clean SwiftUI是将Clean Architecture（整洁架构）的原则与SwiftUI框架相结合的现代iOS应用架构模式。它强调关注点分离、依赖规则和业务逻辑独立性，同时利用SwiftUI的声明式UI和状态管理特性，为开发者提供一种可维护、可测试且灵活的架构方案。

## 核心组件

Clean SwiftUI架构基于Clean Architecture的核心层次，并针对SwiftUI环境进行了调整：

### 实体层（Entities）
- 表示核心业务模型和规则
- 不依赖于任何外部框架
- 包含业务对象和基本验证逻辑

### 用例层（Use Cases）
- 包含应用特定的业务规则
- 协调数据流向实体并从实体获取数据
- 通常实现为服务或交互器（Interactor）

### 接口适配层（Interface Adapters）
- 在SwiftUI中通常表现为ViewModel
- 将用例的数据转换为视图可用的格式
- 处理UI相关的业务逻辑

### 框架层（Frameworks & Drivers）
- 包括SwiftUI视图、数据源和外部服务
- 负责UI渲染和与外部系统的交互
- 依赖于其他所有层，但不被其他层依赖

## 实现方式

以下是Clean SwiftUI架构的基本实现示例：

### 1. 实体层

```swift
// 核心业务模型
struct User: Identifiable, Equatable {
    let id: UUID
    let username: String
    let email: String
    
    // 业务规则验证
    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct Post: Identifiable, Equatable {
    let id: UUID
    let authorId: UUID
    let title: String
    let content: String
    let createdAt: Date
    
    // 业务规则
    var isValid: Bool {
        !title.isEmpty && !content.isEmpty
    }
}
```

### 2. 用例层

```swift
// 用例协议
protocol UserUseCaseProtocol {
    func getUser(id: UUID) async throws -> User
    func updateUser(user: User) async throws -> User
    func searchUsers(query: String) async throws -> [User]
}

protocol PostUseCaseProtocol {
    func getPosts(by userId: UUID) async throws -> [Post]
    func createPost(authorId: UUID, title: String, content: String) async throws -> Post
    func deletePost(id: UUID) async throws
}

// 用例实现
class UserUseCase: UserUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol
    
    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }
    
    func getUser(id: UUID) async throws -> User {
        return try await userRepository.fetchUser(id: id)
    }
    
    func updateUser(user: User) async throws -> User {
        // 在保存前验证业务规则
        guard user.isEmailValid else {
            throw ValidationError.invalidEmail
        }
        
        return try await userRepository.saveUser(user: user)
    }
    
    func searchUsers(query: String) async throws -> [User] {
        return try await userRepository.searchUsers(matching: query)
    }
}

enum ValidationError: Error {
    case invalidEmail
    case invalidPost
}
```

### 3. 接口适配层（ViewModel）

```swift
@Observable
class UserProfileViewModel {
    // 状态
    private(set) var user: User?
    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var error: String?
    
    // 依赖
    private let userUseCase: UserUseCaseProtocol
    private let postUseCase: PostUseCaseProtocol
    
    init(userUseCase: UserUseCaseProtocol, postUseCase: PostUseCaseProtocol) {
        self.userUseCase = userUseCase
        self.postUseCase = postUseCase
    }
    
    // 意图（Intent）
    func loadUserProfile(userId: UUID) async {
        isLoading = true
        error = nil
        
        do {
            // 并行加载用户和帖子
            async let userTask = userUseCase.getUser(id: userId)
            async let postsTask = postUseCase.getPosts(by: userId)
            
            let (fetchedUser, fetchedPosts) = try await (userTask, postsTask)
            
            // 更新UI状态
            user = fetchedUser
            posts = fetchedPosts
            isLoading = false
        } catch {
            self.error = "加载用户资料失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func createNewPost(title: String, content: String) async {
        guard let userId = user?.id else { return }
        isLoading = true
        error = nil
        
        do {
            let newPost = try await postUseCase.createPost(
                authorId: userId,
                title: title,
                content: content
            )
            posts.append(newPost)
            isLoading = false
        } catch {
            self.error = "创建帖子失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
```

### 4. 框架层（SwiftUI视图）

```swift
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel
    @State private var newPostTitle = ""
    @State private var newPostContent = ""
    @State private var isShowingNewPostSheet = false
    
    let userId: UUID
    
    init(userId: UUID, viewModel: UserProfileViewModel) {
        self.userId = userId
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let user = viewModel.user {
                    userProfileHeader(user: user)
                    
                    Divider()
                    
                    postsSection
                }
            }
            .padding()
        }
        .navigationTitle("用户资料")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("新建帖子") {
                    isShowingNewPostSheet = true
                }
                .disabled(viewModel.user == nil)
            }
        }
        .sheet(isPresented: $isShowingNewPostSheet) {
            newPostView
        }
        .task {
            await viewModel.loadUserProfile(userId: userId)
        }
    }
    
    private func userProfileHeader(user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(user.username)
                .font(.title)
                .fontWeight(.bold)
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("帖子")
                .font(.headline)
            
            if viewModel.posts.isEmpty {
                Text("暂无帖子")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.posts) { post in
                    PostRow(post: post)
                }
            }
        }
    }
    
    private var newPostView: some View {
        NavigationView {
            Form {
                Section(header: Text("新建帖子")) {
                    TextField("标题", text: $newPostTitle)
                    
                    ZStack(alignment: .topLeading) {
                        if newPostContent.isEmpty {
                            Text("内容")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $newPostContent)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("创建帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isShowingNewPostSheet = false
                        newPostTitle = ""
                        newPostContent = ""
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        Task {
                            await viewModel.createNewPost(
                                title: newPostTitle,
                                content: newPostContent
                            )
                            isShowingNewPostSheet = false
                            newPostTitle = ""
                            newPostContent = ""
                        }
                    }
                    .disabled(newPostTitle.isEmpty || newPostContent.isEmpty)
                }
            }
        }
    }
}

struct PostRow: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.headline)
            
            Text(post.content)
                .font(.body)
                .lineLimit(3)
            
            Text(post.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### 5. 数据层（Repository）

```swift
// 数据源协议
protocol UserRepositoryProtocol {
    func fetchUser(id: UUID) async throws -> User
    func saveUser(user: User) async throws -> User
    func searchUsers(matching query: String) async throws -> [User]
}

protocol PostRepositoryProtocol {
    func fetchPosts(by userId: UUID) async throws -> [Post]
    func createPost(post: Post) async throws -> Post
    func deletePost(id: UUID) async throws
}

// 实现（例如使用网络API）
class APIUserRepository: UserRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func fetchUser(id: UUID) async throws -> User {
        let endpoint = "users/\(id)"
        return try await apiClient.request(endpoint: endpoint, method: .get)
    }
    
    func saveUser(user: User) async throws -> User {
        let endpoint = "users/\(user.id)"
        return try await apiClient.request(endpoint: endpoint, method: .put, body: user)
    }
    
    func searchUsers(matching query: String) async throws -> [User] {
        let endpoint = "users/search?q=\(query)"
        return try await apiClient.request(endpoint: endpoint, method: .get)
    }
}
```

## 实际案例：任务管理应用

以下是一个完整的Clean SwiftUI任务管理应用示例：

### 实体层

```swift
// 核心业务模型
struct Task: Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool
    var tags: [String]
    
    enum Priority: String, CaseIterable, Codable {
        case low = "低"
        case medium = "中"
        case high = "高"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
    
    // 业务规则
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var isValid: Bool {
        !title.isEmpty
    }
}
```

### 用例层

```swift
// 用例协议
protocol TaskUseCaseProtocol {
    func getTasks() async throws -> [Task]
    func getTask(id: UUID) async throws -> Task
    func createTask(task: Task) async throws -> Task
    func updateTask(task: Task) async throws -> Task
    func deleteTask(id: UUID) async throws
    func completeTask(id: UUID) async throws -> Task
    func getTasksByTag(tag: String) async throws -> [Task]
}

// 用例实现
class TaskUseCase: Task