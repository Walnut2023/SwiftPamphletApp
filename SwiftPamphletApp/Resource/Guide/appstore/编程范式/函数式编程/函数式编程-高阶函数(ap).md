# Swift中的高阶函数

高阶函数是函数式编程中的重要概念，它指的是接受其他函数作为参数或返回函数的函数。Swift提供了多种内置的高阶函数，让我们能够以更简洁、更声明式的方式处理数据。

## 常用高阶函数

### 1. map

map函数将一个转换函数应用到集合的每个元素上：

```swift
// 基础用法
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map { $0 * 2 } // [2, 4, 6, 8, 10]

// 处理复杂对象
struct User {
    let name: String
    let age: Int
}

let users = [User(name: "小明", age: 20), User(name: "小红", age: 22)]
let names = users.map { $0.name } // ["小明", "小红"]
```

### 2. filter

filter函数用于筛选集合中满足条件的元素：

```swift
// 基础过滤
let numbers = [1, 2, 3, 4, 5, 6]
let evenNumbers = numbers.filter { $0 % 2 == 0 } // [2, 4, 6]

// 复杂条件过滤
let users = [User(name: "小明", age: 20), User(name: "小红", age: 22)]
let adults = users.filter { $0.age >= 21 } // [User(name: "小红", age: 22)]
```

### 3. reduce

reduce函数将集合中的元素合并为单个值：

```swift
// 求和
let numbers = [1, 2, 3, 4, 5]
let sum = numbers.reduce(0, +) // 15

// 字符串拼接
let words = ["Hello", "World"]
let sentence = words.reduce("") { $0 + ($0.isEmpty ? "" : " ") + $1 } // "Hello World"
```

## 在SwiftUI中的应用

高阶函数在SwiftUI中有广泛的应用，特别是在数据处理和视图构建方面：

```swift
struct ContentView: View {
    let items = ["苹果", "香蕉", "橙子"]
    
    var body: some View {
        List {
            // 使用map转换数据为视图
            ForEach(items.enumerated().map { index, item in
                (id: index, text: item)
            }, id: \.id) { item in
                Text(item.text)
            }
        }
    }
}
```

## 结合Combine框架

在Combine框架中，高阶函数是处理异步数据流的重要工具：

```swift
class ViewModel: ObservableObject {
    @Published var searchText = ""
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 使用高阶函数处理数据流
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .filter { !$0.isEmpty }
            .map { text -> String in
                // 转换搜索文本
                return text.trimmingCharacters(in: .whitespaces)
            }
            .sink { [weak self] text in
                self?.performSearch(text)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(_ query: String) {
        // 执行搜索操作
    }
}
```

## 自定义高阶函数

我们也可以创建自己的高阶函数来满足特定需求：

```swift
extension Array {
    func customMap<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for element in self {
            result.append(try transform(element))
        }
        return result
    }
}

// 使用示例
let numbers = [1, 2, 3]
let stringNumbers = numbers.customMap { "数字：\($0)" }
// ["数字：1", "数字：2", "数字：3"]
```

## 最佳实践

在使用高阶函数时，应注意以下几点：

1. **可读性优先**：虽然可以链式调用多个高阶函数，但要注意保持代码的可读性。

```swift
// 好的做法
let result = numbers
    .filter { $0 > 0 }
    .map { $0 * 2 }
    .reduce(0, +)

// 避免过度链式调用
```

2. **性能考虑**：在处理大量数据时，考虑使用lazy高阶函数以提高性能。

```swift
let numbers = Array(1...1000000)
let result = numbers.lazy
    .filter { $0 % 2 == 0 }
    .map { $0 * 2 }
    .prefix(5)
```

3. **错误处理**：使用带有throws的高阶函数版本来处理可能的错误。

```swift
func processItems<T>(_ items: [T]) throws {
    try items.forEach { item in
        try processItem(item)
    }
}
```

## 总结

高阶函数是Swift中强大的函数式编程工具，它们能够：

- 使代码更加简洁和声明式
- 提高代码的可读性和可维护性
- 减少重复代码
- 方便进行函数组合

通过合理使用高阶函数，我们可以编写出更优雅、更易维护的代码。在实际开发中，应根据具体场景选择合适的高阶函数，并注意平衡代码的简洁性和性能需求。