# SwiftUI状态管理

## 简介

SwiftUI采用声明式UI和响应式编程范式，通过状态管理机制实现UI与数据的自动同步。本文将详细介绍SwiftUI中的各种状态管理方式。

## 基础状态管理

### 1. @State
```swift
// 基本用法
struct ContentView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("计数: \(count)")
            Button("增加") {
                count += 1
            }
        }
    }
}
```

### 2. @Binding
```swift
// 子视图接收父视图的状态
struct ToggleView: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("开关", isOn: $isOn)
    }
}

// 父视图
struct ParentView: View {
    @State private var isOn = false
    
    var body: some View {
        ToggleView(isOn: $isOn)
    }
}
```

## 对象状态管理

### 1. @StateObject
```swift
// 数据模型
class UserViewModel: ObservableObject {
    @Published var username = ""
    @Published var isLoggedIn = false
    
    func login() {
        // 登录逻辑
        isLoggedIn = true
    }
}

// 视图
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        VStack {
            TextField("用户名", text: $viewModel.username)
            Button("登录") {
                viewModel.login()
            }
        }
    }
}
```

### 2. @ObservedObject
```swift
// 子视图
struct ProfileView: View {
    @ObservedObject var viewModel: UserViewModel
    
    var body: some View {
        Text(viewModel.username)
    }
}
```

## 环境状态管理

### 1. @EnvironmentObject
```swift
// 全局状态
class AppState: ObservableObject {
    @Published var theme = "light"
    @Published var language = "zh"
}

// 根视图
struct RootView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        ContentView()
            .environmentObject(appState)
    }
}

// 子视图
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            Toggle("深色模式", isOn: Binding(
                get: { appState.theme == "dark" },
                set: { appState.theme = $0 ? "dark" : "light" }
            ))
        }
    }
}
```

### 2. @Environment
```swift
// 使用系统环境值
struct AdaptiveView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text("当前主题: \(colorScheme == .dark ? "深色" : "浅色")")
    }
}
```

## 高级状态管理

### 1. 自定义属性包装器
```swift
// 持久化状态包装器
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

// 使用示例
struct SettingsView: View {
    @UserDefault(key: "isDarkMode", defaultValue: false)
    var isDarkMode: Bool
    
    var body: some View {
        Toggle("深色模式", isOn: $isDarkMode)
    }
}
```

### 2. 状态恢复
```swift
// 支持状态恢复的视图
struct RestoringView: View {
    @SceneStorage("selectedTab") private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Text("首页").tag(0)
            Text("设置").tag(1)
        }
    }
}
```

## 最佳实践

### 1. 状态提升
```swift
// 将共享状态提升到父视图
struct ParentView: View {
    @State private var sharedData = ""
    
    var body: some View {
        VStack {
            ChildView1(data: $sharedData)
            ChildView2(data: $sharedData)
        }
    }
}
```

### 2. 状态隔离
```swift
// 将局部状态保持在组件内部
struct LocalStateView: View {
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: { Text("详细内容") },
            label: { Text("展开/收起") }
        )
    }
}
```

## 性能优化

### 1. 避免过度观察
```swift
// 使用Equatable减少更新
struct OptimizedView: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        // 只在relevant属性变化时更新
        Text(viewModel.relevant)
            .onChange(of: viewModel.relevant) { newValue in
                // 处理变化
            }
    }
}
```

### 2. 视图拆分
```swift
// 将大型视图拆分为小组件
struct ComplexView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        VStack {
            HeaderView(title: viewModel.title)
            ContentView(data: viewModel.data)
            FooterView(isLoading: viewModel.isLoading)
        }
    }
}
```

## 注意事项

1. **状态管理选择**
   - @State用于简单的值类型
   - @StateObject用于引用类型
   - @EnvironmentObject用于全局状态

2. **性能考虑**
   - 避免不必要的状态更新
   - 合理使用视图结构

3. **调试技巧**
   - 使用PreviewProvider测试状态变化
   - 善用print调试状态更新

## 总结

SwiftUI的状态管理机制提供了一种优雅的方式来处理UI和数据的同步。通过合理使用各种状态管理工具，我们可以构建出响应迅速、易于维护的应用程序。在实际开发中，需要根据具体场景选择合适的状态管理方式，并注意性能优化。