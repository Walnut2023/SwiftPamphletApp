# Swift中的类和继承

Swift作为一门现代编程语言，提供了强大而灵活的类和继承机制。本文将详细介绍Swift中类的定义、属性、方法以及继承的使用。

## 1. 类的定义和基本特性

在Swift中，类是引用类型，可以包含属性、方法、下标和初始化器。

```swift
class Person {
    // 存储属性
    var name: String
    var age: Int
    
    // 计算属性
    var description: String {
        return "\(name), \(age)岁"
    }
    
    // 属性观察器
    var score: Int = 0 {
        willSet {
            print("分数将要从\(score)变为\(newValue)")
        }
        didSet {
            print("分数已从\(oldValue)变为\(score)")
        }
    }
    
    // 初始化器
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    // 实例方法
    func introduce() {
        print("我是\(name)，今年\(age)岁")
    }
    
    // 类方法
    static func createAdult(name: String) -> Person {
        return Person(name: name, age: 18)
    }
}

// 使用示例
let person = Person(name: "张三", age: 25)
person.introduce()  // 输出：我是张三，今年25岁
person.score = 90   // 触发属性观察器
```

## 2. 继承和方法重写

Swift支持单继承，子类可以继承父类的属性和方法，并可以添加新的特性或重写现有特性。

```swift
// 学生类继承自Person类
class Student: Person {
    var grade: String
    
    // 重写计算属性
    override var description: String {
        return "\(name), \(age)岁, \(grade)年级"
    }
    
    // 子类初始化器
    init(name: String, age: Int, grade: String) {
        self.grade = grade
        super.init(name: name, age: age)
    }
    
    // 重写方法
    override func introduce() {
        print("我是\(grade)年级的\(name)，今年\(age)岁")
    }
    
    // 子类特有方法
    func study() {
        print("\(name)正在学习")
    }
}

// 使用示例
let student = Student(name: "小明", age: 15, grade: "初三")
student.introduce()  // 输出：我是初三年级的小明，今年15岁
student.study()     // 输出：小明正在学习
```

## 3. 类型转换和类型检查

Swift提供了类型转换和检查机制，用于在运行时处理类的层次结构。

```swift
// 定义一些类
class MediaItem {
    var name: String
    init(name: String) {
        self.name = name
    }
}

class Movie: MediaItem {
    var director: String
    init(name: String, director: String) {
        self.director = director
        super.init(name: name)
    }
}

class Song: MediaItem {
    var artist: String
    init(name: String, artist: String) {
        self.artist = artist
        super.init(name: name)
    }
}

// 类型转换示例
let library = [
    Movie(name: "星际穿越", director: "克里斯托弗·诺兰"),
    Song(name: "晴天", artist: "周杰伦"),
    Movie(name: "盗梦空间", director: "克里斯托弗·诺兰")
]

// 使用 is 进行类型检查
for item in library {
    if item is Movie {
        print("\(item.name) 是一部电影")
    } else if item is Song {
        print("\(item.name) 是一首歌")
    }
}

// 使用 as? 进行可选类型转换
for item in library {
    if let movie = item as? Movie {
        print("电影：\(movie.name)，导演：\(movie.director)")
    } else if let song = item as? Song {
        print("歌曲：\(song.name)，歌手：\(song.artist)")
    }
}
```

## 4. 访问控制

Swift提供了多个访问级别，用于控制代码的可见性和封装性。

```swift
// 公开类
public class PublicClass {
    // 公开属性，所有地方都可访问
    public var publicProperty: String
    
    // 内部属性，只在模块内可访问
    internal var internalProperty: String
    
    // 私有属性，只在类内可访问
    private var privateProperty: String
    
    // 文件私有属性，只在当前文件内可访问
    fileprivate var filePrivateProperty: String
    
    public init() {
        publicProperty = "公开"
        internalProperty = "内部"
        privateProperty = "私有"
        filePrivateProperty = "文件私有"
    }
}
```

## 5. 类的高级特性

### 5.1 必要初始化器

```swift
class RequiredInitClass {
    var name: String
    
    // 必要初始化器，所有子类都必须实现
    required init(name: String) {
        self.name = name
    }
}

class SubClass: RequiredInitClass {
    var age: Int
    
    // 子类必须实现必要初始化器
    required init(name: String) {
        self.age = 0
        super.init(name: name)
    }
}
```

### 5.2 便利初始化器

```swift
class Food {
    var name: String
    var price: Double
    
    // 指定初始化器
    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
    
    // 便利初始化器
    convenience init(name: String) {
        self.init(name: name, price: 0.0)
    }
}
```

## 最佳实践

1. **合理使用访问控制**：根据实际需求选择合适的访问级别，避免过度暴露内部实现。

2. **初始化器设计**：
   - 使用必要初始化器确保子类实现特定功能
   - 使用便利初始化器提供更方便的对象创建方式

3. **继承层次控制**：
   - 避免过深的继承层次
   - 优先使用组合而不是继承
   - 使用 final 关键字防止不必要的继承

4. **类型安全**：
   - 合理使用类型转换和检查
   - 优先使用可选绑定和类型检查，避免强制转换

5. **内存管理**：
   - 注意引用循环
   - 适当使用weak和unowned引用

通过合理运用Swift的类和继承特性，我们可以构建出结构清晰、易于维护的面向对象程序。在实际开发中，需要根据具体需求选择合适的设计方案，平衡代码的灵活性和复杂性。