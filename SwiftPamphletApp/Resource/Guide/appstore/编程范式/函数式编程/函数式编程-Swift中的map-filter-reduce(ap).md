# Swift中的map、filter和reduce

map、filter和reduce是Swift中最基础且最常用的函数式操作。它们让我们能够以声明式的方式处理集合数据，使代码更加简洁和易于理解。

## map 转换操作

map函数用于将集合中的每个元素转换为新的形式，而不改变原集合：

```swift
// 基础数值转换
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map { $0 * 2 } // [2, 4, 6, 8, 10]

// 字符串处理
let words = ["hello", "world"]
let uppercased = words.map { $0.uppercased() } // ["HELLO", "WORLD"]

// 对象转换
struct User {
    let id: Int
    let name: String
}

let users = [User(id: 1, name: "小明"), User(id: 2, name: "小红")]
let userNames = users.map { $0.name } // ["小明", "小红"]
```

## filter 过滤操作

filter函数用于根据条件筛选集合中的元素：

```swift
// 数值过滤
let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let evenNumbers = numbers.filter { $0 % 2 == 0 } // [2, 4, 6, 8, 10]

// 字符串过滤
let words = ["Swift", "Objective-C", "Ruby", "Python"]
let longWords = words.filter { $0.count > 5 } // ["Objective-C", "Python"]

// 复杂对象过滤
struct Task {
    let title: String
    let isCompleted: Bool
}

let tasks = [
    Task(title: "学习Swift", isCompleted: true),
    Task(title: "写作业", isCompleted: false),
    Task(title: "看书", isCompleted: true)
]

let completedTasks = tasks.filter { $0.isCompleted } // 只包含已完成的任务
```

## reduce 合并操作

reduce函数用于将集合中的所有元素合并为一个值：

```swift
// 数值求和
let numbers = [1, 2, 3, 4, 5]
let sum = numbers.reduce(0, +) // 15

// 字符串拼接
let words = ["Hello", "World"]
let combined = words.reduce("") { $0 + ($0.isEmpty ? "" : " ") + $1 } // "Hello World"

// 自定义合并逻辑
struct CartItem {
    let name: String
    let price: Double
}

let items = [
    CartItem(name: "苹果", price: 5.0),
    CartItem(name: "香蕉", price: 3.0),
    CartItem(name: "橙子", price: 4.0)
]

let totalPrice = items.reduce(0.0) { $0 + $1.price } // 12.0
```

## 链式操作

这三个函数可以组合使用，形成强大的数据处理管道：

```swift
// 示例：处理购物车数据
struct CartItem {
    let name: String
    let price: Double
    let quantity: Int
}

let cart = [
    CartItem(name: "苹果", price: 5.0, quantity: 3),
    CartItem(name: "香蕉", price: 3.0, quantity: 2),
    CartItem(name: "橙子", price: 4.0, quantity: 0)
]

// 计算有库存商品的总价
let totalPrice = cart
    .filter { $0.quantity > 0 } // 过滤掉无库存商品
    .map { $0.price * Double($0.quantity) } // 计算每件商品总价
    .reduce(0, +) // 求和

print(totalPrice) // 21.0 (苹果15.0 + 香蕉6.0)
```

## 性能优化

在处理大量数据时，可以使用lazy操作来提高性能：

```swift
// 使用lazy优化性能
let numbers = Array(1...1000000)
let result = numbers.lazy
    .filter { $0 % 2 == 0 }
    .map { $0 * 2 }
    .prefix(5)

print(Array(result)) // 只计算需要的前5个元素
```

## 实际应用场景

### 1. 数据转换

```swift
// API响应处理
struct APIResponse {
    let id: Int
    let data: String
}

let responses = [APIResponse(id: 1, data: "A"), APIResponse(id: 2, data: "B")]
let ids = responses.map { $0.id } // 提取ID列表
```

### 2. 数据验证

```swift
// 表单验证
struct FormField {
    let name: String
    let value: String
    var isValid: Bool {
        !value.isEmpty
    }
}

let fields = [
    FormField(name: "用户名", value: "张三"),
    FormField(name: "邮箱", value: "")
]

let isFormValid = fields.filter { !$0.isValid }.isEmpty
```

### 3. 数据统计

```swift
// 销售数据分析
struct Sale {
    let product: String
    let amount: Double
    let date: Date
}

let sales = [/* 销售数据 */]

// 计算每个产品的总销售额
let productTotals = Dictionary(grouping: sales, by: { $0.product })
    .mapValues { sales in
        sales.reduce(0) { $0 + $1.amount }
    }
```

## 最佳实践

1. **可读性优先**：虽然可以链式调用多个函数，但要注意保持代码的可读性。适当换行和添加注释。

2. **选择合适的操作**：根据实际需求选择合适的函数：
   - 需要转换元素？使用 map
   - 需要筛选元素？使用 filter
   - 需要合并元素？使用 reduce

3. **考虑性能**：处理大量数据时，合理使用lazy操作来优化性能。

4. **保持简单**：每个操作应该只做一件事，避免在闭包中写复杂的逻辑。

通过合理使用这些函数式操作，我们可以写出更简洁、更易维护的代码。在实际开发中，这些操作几乎无处不在，掌握它们是提高代码质量的重要一步。