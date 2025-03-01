# Swift中的函数式编程实现

## 纯函数实现

纯函数是函数式编程的核心概念之一，它具有以下特征：
- 相同输入总是产生相同输出
- 没有副作用
- 不依赖外部状态

```swift
// 纯函数示例
func add(_ a: Int, _ b: Int) -> Int {
    return a + b
}

// 非纯函数示例（依赖外部状态）
var total = 0
func addToTotal(_ value: Int) {
    total += value // 修改外部状态
}
```

## 高阶函数实现

### 1. map 实现

```swift
extension Array {
    func customMap<T>(_ transform: (Element) -> T) -> [T] {
        var result: [T] = []
        for item in self {
            result.append(transform(item))
        }
        return result
    }
}

// 使用示例
let numbers = [1, 2, 3]
let doubled = numbers.customMap { $0 * 2 } // [2, 4, 6]
```

### 2. filter 实现

```swift
extension Array {
    func customFilter(_ isIncluded: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        for item in self {
            if isIncluded(item) {
                result.append(item)
            }
        }
        return result
    }
}

// 使用示例
let evenNumbers = numbers.customFilter { $0 % 2 == 0 } // [2]
```

### 3. reduce 实现

```swift
extension Array {
    func customReduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) -> T) -> T {
        var result = initialResult
        for item in self {
            result = nextPartialResult(result, item)
        }
        return result
    }
}

// 使用示例
let sum = numbers.customReduce(0, +) // 6
```

## 函数组合实现

### 1. 基本函数组合运算符

```swift
infix operator >>> : CompositePrecedence
precedencegroup CompositePrecedence {
    associativity: left
    higherThan: AssignmentPrecedence
}

func >>> <A, B, C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    return { x in g(f(x)) }
}

// 使用示例
func increment(_ x: Int) -> Int { x + 1 }
func double(_ x: Int) -> Int { x * 2 }

let incrementThenDouble = increment >>> double
let result = incrementThenDouble(3) // 8
```

## 在SwiftUI中的应用

### 1. 视图转换函数

```swift
struct ContentView: View {
    let transform: (String) -> String = { str in
        str.uppercased()
    } >>> { str in
        "Hello, \(str)!"
    }
    
    var body: some View {
        Text(transform("world")) // 显示 "Hello, WORLD!"
    }
}
```

### 2. 数据流处理

```swift
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func processItems() {
        let process = filterActiveItems
            >>> sortByPriority
            >>> limitToTop10
        
        items = process(items)
    }
    
    private func filterActiveItems(_ items: [Item]) -> [Item] {
        items.filter { $0.isActive }
    }
    
    private func sortByPriority(_ items: [Item]) -> [Item] {
        items.sorted { $0.priority > $1.priority }
    }
    
    private func limitToTop10(_ items: [Item]) -> [Item] {
        Array(items.prefix(10))
    }
}
```

## Combine框架中的应用

```swift
class DataProcessor {
    let processPublisher: AnyPublisher<[String], Never>
    
    init(input: [String]) {
        processPublisher = Just(input)
            .map { strings in
                strings.map { $0.uppercased() }
            }
            .map { strings in
                strings.filter { !$0.isEmpty }
            }
            .map { strings in
                strings.sorted()
            }
            .eraseToAnyPublisher()
    }
}
```

## 性能优化

### 1. 惰性求值

```swift
// 使用lazy避免不必要的计算
let numbers = Array(1...1000000)
let result = numbers.lazy
    .filter { $0 % 2 == 0 }
    .map { $0 * 2 }
    .prefix(5)
```

### 2. 避免中间数组

```swift
// 不推荐：创建多个中间数组
let result1 = numbers
    .map { $0 * 2 }
    .filter { $0 % 4 == 0 }

// 推荐：使用reduce合并操作
let result2 = numbers.reduce(into: [Int]()) { result, number in
    let doubled = number * 2
    if doubled % 4 == 0 {
        result.append(doubled)
    }
}
```

## 最佳实践

1. **适度使用函数式编程**
   - 在适当的场景选择函数式编程
   - 避免过度组合导致代码难以理解

2. **保持函数纯净**
   - 尽可能使用纯函数
   - 将副作用隔离在特定层级

3. **类型安全**
   - 利用Swift的类型系统确保函数组合的类型安全
   - 使用泛型增加代码复用性

4. **性能考虑**
   - 合理使用惰性求值
   - 注意内存使用和调用栈深度

5. **测试友好**
   - 纯函数易于测试
   - 函数组合便于单元测试

通过合理运用这些函数式编程特性，我们可以在Swift项目中编写出更加简洁、可维护和可测试的代码。同时，结合Swift的强大类型系统和现代框架（如SwiftUI和Combine），可以充分发挥函数式编程的优势。