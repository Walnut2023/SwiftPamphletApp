# Swift DSL设计

## 什么是DSL

DSL（Domain-Specific Language，领域特定语言）是为解决特定领域问题而设计的专门语言。在Swift中，我们可以通过语言的特性来创建流畅、直观的DSL。

## DSL的特点

1. **领域专注性**：专门解决特定问题
2. **声明式语法**：注重表达意图而非实现细节
3. **流畅的API**：链式调用，自然语言式的表达
4. **类型安全**：编译时检查，避免运行时错误

## Swift DSL实现技术

### 1. 函数构建器
```swift
@resultBuilder
struct HTMLBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }
}

@HTMLBuilder
func makeHTML() -> String {
    "<html>"
    "<body>"
    "<h1>Hello, World!</h1>"
    "</body>"
    "</html>"
}
```

### 2. 方法链式调用
```swift
struct QueryBuilder {
    private var query = ""
    
    func select(_ fields: String...) -> QueryBuilder {
        var builder = self
        builder.query += "SELECT " + fields.joined(separator: ", ")
        return builder
    }
    
    func from(_ table: String) -> QueryBuilder {
        var builder = self
        builder.query += " FROM " + table
        return builder
    }
    
    func build() -> String {
        return query
    }
}

// 使用示例
let query = QueryBuilder()
    .select("id", "name", "age")
    .from("users")
    .build()
```

### 3. 运算符重载
```swift
struct CSS {
    let properties: [String: String]
    
    static func + (left: CSS, right: CSS) -> CSS {
        CSS(properties: left.properties.merging(right.properties) { $1 })
    }
}

let baseStyle = CSS(properties: ["font-size": "16px"])
let boldStyle = CSS(properties: ["font-weight": "bold"])
let combinedStyle = baseStyle + boldStyle
```

## SwiftUI中的DSL

### 1. 视图构建器
```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello")
                .font(.title)
            
            HStack {
                Image(systemName: "star")
                Text("Rating")
            }
            .padding()
        }
    }
}
```

### 2. 自定义视图构建器
```swift
@resultBuilder
struct ArrayBuilder {
    static func buildBlock<T>(_ components: T...) -> [T] {
        components
    }
}

struct ListView {
    @ArrayBuilder
    var content: () -> [String]
    
    func render() {
        content().forEach { print($0) }
    }
}

let list = ListView {
    "Item 1"
    "Item 2"
    "Item 3"
}
```

## 最佳实践

### 1. API设计原则
```swift
struct MenuBuilder {
    private var items: [MenuItem] = []
    
    func addItem(
        title: String,
        action: @escaping () -> Void
    ) -> MenuBuilder {
        var builder = self
        builder.items.append(MenuItem(title: title, action: action))
        return builder
    }
    
    func build() -> Menu {
        Menu(items: items)
    }
}

// 使用示例
let menu = MenuBuilder()
    .addItem(title: "New") { print("New item") }
    .addItem(title: "Open") { print("Open item") }
    .build()
```

### 2. 错误处理
```swift
struct ValidatedForm {
    private var validations: [(String, String?) -> Bool] = []
    
    func validate(_ field: String, rule: @escaping (String?) -> Bool) -> ValidatedForm {
        var form = self
        form.validations.append({ name, value in
            name == field ? rule(value) : true
        })
        return form
    }
    
    func isValid(field: String, value: String?) -> Bool {
        validations.allSatisfy { $0(field, value) }
    }
}

// 使用示例
let form = ValidatedForm()
    .validate("email") { $0?.contains("@") ?? false }
    .validate("password") { $0?.count ?? 0 >= 8 }
```

### 3. 性能考虑
- 避免过度嵌套
- 合理使用值类型和引用类型
- 注意内存管理

## 应用场景

1. **UI构建**
   - 视图层次结构
   - 样式定义
   - 动画配置

```swift
// UI构建场景示例：自定义视图DSL
@resultBuilder
struct ViewBuilder {
    static func buildBlock(_ components: UIView...) -> [UIView] {
        components
    }
}

class ContainerView: UIView {
    @ViewBuilder
    var content: () -> [UIView]
    
    init(@ViewBuilder content: @escaping () -> [UIView]) {
        self.content = content
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        content().forEach { view in
            addSubview(view)
        }
    }
}

// 使用示例
let container = ContainerView {
    let label = UILabel()
    label.text = "Hello"
    label
    
    let button = UIButton(type: .system)
    button.setTitle("Click me", for: .normal)
    button
}
```

2. **数据处理**
   - 查询语言
   - 数据转换
   - 验证规则

```swift
// 数据处理场景示例：查询语言DSL
struct Query<T> {
    private var predicates: [String] = []
    private var sortDescriptors: [String] = []
    private var limit: Int?
    
    func filter(_ condition: String) -> Query<T> {
        var query = self
        query.predicates.append(condition)
        return query
    }
    
    func sort(by field: String, ascending: Bool = true) -> Query<T> {
        var query = self
        query.sortDescriptors.append("\(field) \(ascending ? "ASC" : "DESC")")
        return query
    }
    
    func limit(_ count: Int) -> Query<T> {
        var query = self
        query.limit = count
        return query
    }
    
    func build() -> String {
        var sql = "SELECT * FROM \(String(describing: T.self))"
        
        if !predicates.isEmpty {
            sql += " WHERE " + predicates.joined(separator: " AND ")
        }
        
        if !sortDescriptors.isEmpty {
            sql += " ORDER BY " + sortDescriptors.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        
        return sql
    }
}

// 使用示例
struct User {}
let query = Query<User>()
    .filter("age > 18")
    .filter("status = 'active'")
    .sort(by: "created_at", ascending: false)
    .limit(10)
    .build()
```

3. **配置管理**
   - 网络请求
   - 应用设置
   - 主题定制

```swift
// 配置管理场景示例：网络请求DSL
struct NetworkRequest {
    private var baseURL: String
    private var path: String = ""
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var parameters: [String: Any] = [:]
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func path(_ path: String) -> NetworkRequest {
        var request = self
        request.path = path
        return request
    }
    
    func method(_ method: String) -> NetworkRequest {
        var request = self
        request.method = method
        return request
    }
    
    func header(key: String, value: String) -> NetworkRequest {
        var request = self
        request.headers[key] = value
        return request
    }
    
    func parameter(key: String, value: Any) -> NetworkRequest {
        var request = self
        request.parameters[key] = value
        return request
    }
    
    func build() -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        
        if method == "GET" {
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: String(describing: value))
            }
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        
        headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        if method != "GET" {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        return request
    }
}

// 使用示例
let request = NetworkRequest(baseURL: "https://api.example.com")
    .path("/users")
    .method("POST")
    .header(key: "Content-Type", value: "application/json")
    .header(key: "Authorization", value: "Bearer token")
    .parameter(key: "name", value: "John")
    .parameter(key: "age", value: 30)
    .build()
```

## 注意事项
- **可读性**：DSL应易于理解和维护
- **性能**：DSL应在性能要求下进行优化
- **错误处理**：DSL应提供错误处理机制

Swift的DSL设计能力为我们提供了创建声明式、类型安全且易于使用的API的强大工具。通过合理运用函数构建器、方法链式调用和运算符重载等特性，我们可以设计出既优雅又实用的领域特定语言。在实际开发中，应该根据具体需求选择合适的DSL设计方案，并注意平衡易用性和性能。