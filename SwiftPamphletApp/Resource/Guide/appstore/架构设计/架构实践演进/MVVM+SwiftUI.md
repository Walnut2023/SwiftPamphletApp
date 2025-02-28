# MVVM+SwiftUI架构模式

## 架构概述

MVVM+SwiftUI是将传统的MVVM（Model-View-ViewModel）架构模式与SwiftUI框架相结合的现代iOS应用架构。在这种架构中，SwiftUI视图订阅ViewModel中的状态变化，实现了声明式UI与响应式编程的完美结合。

## 核心组件

### Model
- 代表应用的数据模型和业务逻辑
- 负责数据的获取、存储和处理
- 与具体的UI实现无关

### ViewModel
- 作为View和Model之间的中介
- 处理UI相关的业务逻辑
- 提供可观察的状态供View订阅
- 在SwiftUI中通常使用`@Observable`、`@Published`或Combine实现

### View
- 使用SwiftUI实现的声明式UI
- 通过`@ObservedObject`、`@StateObject`或新的`@Bindable`订阅ViewModel
- 仅负责UI的渲染，不包含业务逻辑

## 实现方式

在SwiftUI中实现MVVM架构有多种方式，以下是最常见的几种：

### 1. 使用@Observable (iOS 17+)

```swift
@Observable
class UserViewModel {
    var user: User?
    var isLoading = false
    var errorMessage: String?
    
    func fetchUser(id: String) {
        isLoading = true
        errorMessage = nil
        
        // 网络请求获取用户数据
        UserService.shared.fetchUser(id: id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let user):
                    self?.user = user
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

### 2. 使用@Published和ObservableObject

```swift
class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchProducts() {
        isLoading = true
        errorMessage = nil
        
        ProductService.shared.fetchProducts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let products):
                    self?.products = products
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

## 视图实现

```swift
struct ProductListView: View {
    @StateObject private var viewModel = ProductViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    List(viewModel.products) { product in
                        ProductRow(product: product)
                    }
                }
            }
            .navigationTitle("产品列表")
        }
        .onAppear {
            viewModel.fetchProducts()
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(product.name)
                .font(.headline)
            Text(product.description)
                .font(.subheadline)
            Text("¥\(product.price, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

## 实际案例：用户资料管理

以下是一个完整的MVVM+SwiftUI实现案例，展示了用户资料的查看和编辑功能：

### 模型

```swift
struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var bio: String
    var avatarURL: URL?
}
```

### 视图模型

```swift
@Observable
class UserProfileViewModel {
    private let userService: UserServiceProtocol
    
    var user: User?
    var isLoading = false
    var errorMessage: String?
    var isSaving = false
    
    init(userService: UserServiceProtocol = UserService.shared) {
        self.userService = userService
    }
    
    func fetchUserProfile(userId: String) {
        isLoading = true
        errorMessage = nil
        
        userService.fetchUser(id: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let user):
                    self?.user = user
                case .failure(let error):
                    self?.errorMessage = "获取用户资料失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateUserProfile(name: String, bio: String) {
        guard var updatedUser = user else { return }
        
        updatedUser.name = name
        updatedUser.bio = bio
        
        isSaving = true
        errorMessage = nil
        
        userService.updateUser(updatedUser) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSaving = false
                
                switch result {
                case .success(let updatedUser):
                    self?.user = updatedUser
                case .failure(let error):
                    self?.errorMessage = "更新用户资料失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

### 视图

```swift
struct UserProfileView: View {
    @State private var viewModel = UserProfileViewModel()
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedBio = ""
    
    let userId: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if let user = viewModel.user {
                    userProfileContent(user: user)
                }
            }
            .padding()
        }
        .navigationTitle("用户资料")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button("编辑") {
                        editedName = viewModel.user?.name ?? ""
                        editedBio = viewModel.user?.bio ?? ""
                        isEditing = true
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            editProfileView
        }
        .onAppear {
            viewModel.fetchUserProfile(userId: userId)
        }
    }
    
    private func userProfileContent(user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let avatarURL = user.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
            }
            
            Text(user.name)
                .font(.title)
                .fontWeight(.bold)
            
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("个人简介")
                .font(.headline)
            
            Text(user.bio)
                .font(.body)
        }
    }
    
    private var editProfileView: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("姓名", text: $editedName)
                    
                    Section(header: Text("个人简介")) {
                        TextEditor(text: $editedBio)
                            .frame(height: 150)
                    }
                }
            }
            .navigationTitle("编辑资料")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isEditing = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.updateUserProfile(name: editedName, bio: editedBio)
                        isEditing = false
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}
```

## 优点

1. **关注点分离**：视图只负责UI渲染，ViewModel处理业务逻辑，Model负责数据管理
2. **可测试性**：ViewModel可以独立于UI进行单元测试
3. **状态管理清晰**：通过响应式编程，状态变化自动触发UI更新
4. **代码复用**：ViewModel可以被多个视图共享
5. **与SwiftUI完美结合**：利用SwiftUI的声明式特性和数据绑定机制

## 缺点

1. **状态管理复杂度**：随着应用规模增长，状态管理可能变得复杂
2. **内存管理**：需要注意循环引用问题
3. **学习曲线**：需要理解响应式编程和SwiftUI的数据流

## 适用场景

- 中小型应用
- 需要清晰分离UI和业务逻辑的项目
- 团队成员熟悉MVVM模式
- 需要良好测试覆盖率的项目

MVVM+SwiftUI是目前iOS开发中最流行的架构模式之一，它结合了传统MVVM的优势和SwiftUI的现代特性，为开发者提供了一种清晰、可维护的应用架构方案。