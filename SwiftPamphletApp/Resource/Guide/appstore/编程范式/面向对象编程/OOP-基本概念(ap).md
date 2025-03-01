# 面向对象编程基本概念

面向对象编程（Object-Oriented Programming，简称OOP）是一种编程范式，它使用对象来组织和构建程序。在Swift中，我们可以通过类、结构体和协议来实现面向对象编程的核心概念。

## 1. 封装（Encapsulation）

封装是将数据和操作数据的方法绑定在一起，对外部隐藏实现细节的一种机制。

```swift
// 银行账户示例
class BankAccount {
    // 私有属性，外部无法直接访问
    private var balance: Double
    private let accountNumber: String
    
    init(initialBalance: Double, accountNumber: String) {
        self.balance = initialBalance
        self.accountNumber = accountNumber
    }
    
    // 公开方法，提供安全的操作接口
    func deposit(amount: Double) {
        guard amount > 0 else {
            print("存款金额必须大于0")
            return
        }
        balance += amount
        print("存款成功，当前余额：\(balance)")
    }
    
    func withdraw(amount: Double) -> Bool {
        guard amount > 0 else {
            print("取款金额必须大于0")
            return false
        }
        
        guard balance >= amount else {
            print("余额不足")
            return false
        }
        
        balance -= amount
        print("取款成功，当前余额：\(balance)")
        return true
    }
    
    func getBalance() -> Double {
        return balance
    }
}

// 使用示例
let account = BankAccount(initialBalance: 1000, accountNumber: "1234567890")
account.deposit(amount: 500)    // 存款成功，当前余额：1500
account.withdraw(amount: 2000)  // 余额不足
```

## 2. 继承（Inheritance）

继承允许我们创建一个类作为另一个类的基础，继承类的属性和方法。

```swift
// 动物基类
class Animal {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    func makeSound() {
        print("动物发出声音")
    }
}

// 猫类继承自动物类
class Cat: Animal {
    let breed: String
    
    init(name: String, breed: String) {
        self.breed = breed
        super.init(name: name)
    }
    
    // 重写父类方法
    override func makeSound() {
        print("\(name) 喵喵叫")
    }
    
    // 子类特有方法
    func scratch() {
        print("\(name) 在挠东西")
    }
}

// 使用示例
let cat = Cat(name: "咪咪", breed: "英短")
cat.makeSound()  // 咪咪 喵喵叫
cat.scratch()    // 咪咪 在挠东西
```

## 3. 多态（Polymorphism）

多态允许我们以统一的方式处理不同类型的对象。在Swift中，我们可以通过协议和类继承来实现多态。

```swift
// 形状协议
protocol Shape {
    func area() -> Double
    func perimeter() -> Double
}

// 圆形
class Circle: Shape {
    let radius: Double
    
    init(radius: Double) {
        self.radius = radius
    }
    
    func area() -> Double {
        return Double.pi * radius * radius
    }
    
    func perimeter() -> Double {
        return 2 * Double.pi * radius
    }
}

// 矩形
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
    
    func perimeter() -> Double {
        return 2 * (width + height)
    }
}

// 使用多态处理不同形状
func printShapeInfo(_ shape: Shape) {
    print("面积：\(shape.area())")
    print("周长：\(shape.perimeter())")
}

let circle = Circle(radius: 5)
let rectangle = Rectangle(width: 4, height: 6)

printShapeInfo(circle)     // 使用同一个函数处理圆形
printShapeInfo(rectangle)  // 使用同一个函数处理矩形
```

## 4. 抽象和接口

Swift通过协议（Protocol）来实现抽象和接口的概念，这允许我们定义一组方法和属性的规范，而不涉及具体实现。

```swift
// 支付方式接口
protocol PaymentMethod {
    var name: String { get }
    func processPayment(amount: Double) -> Bool
}

// 信用卡支付
class CreditCardPayment: PaymentMethod {
    let name: String
    private let cardNumber: String
    
    init(cardNumber: String) {
        self.name = "信用卡支付"
        self.cardNumber = cardNumber
    }
    
    func processPayment(amount: Double) -> Bool {
        // 实际应用中这里会有真实的支付处理逻辑
        print("使用信用卡 \(cardNumber) 支付 \(amount) 元")
        return true
    }
}

// 支付宝支付
class AlipayPayment: PaymentMethod {
    let name: String
    private let accountId: String
    
    init(accountId: String) {
        self.name = "支付宝支付"
        self.accountId = accountId
    }
    
    func processPayment(amount: Double) -> Bool {
        print("使用支付宝账号 \(accountId) 支付 \(amount) 元")
        return true
    }
}

// 支付处理器
class PaymentProcessor {
    func makePayment(amount: Double, method: PaymentMethod) {
        print("开始使用\(method.name)处理支付...")
        if method.processPayment(amount: amount) {
            print("支付成功！")
        } else {
            print("支付失败！")
        }
    }
}

// 使用示例
let creditCard = CreditCardPayment(cardNumber: "1234-5678-9012-3456")
let alipay = AlipayPayment(accountId: "user@example.com")

let processor = PaymentProcessor()
processor.makePayment(amount: 100, method: creditCard)
processor.makePayment(amount: 200, method: alipay)
```

## 最佳实践

1. **单一职责原则**：每个类应该只有一个改变的理由。
2. **封装细节**：将实现细节隐藏在私有属性和方法中。
3. **合理使用继承**：优先使用组合而不是继承，避免过深的继承层次。
4. **面向接口编程**：通过协议定义接口，实现松耦合的设计。
5. **遵循SOLID原则**：
   - 单一职责原则（Single Responsibility Principle）
   - 开闭原则（Open/Closed Principle）
   - 里氏替换原则（Liskov Substitution Principle）
   - 接口隔离原则（Interface Segregation Principle）
   - 依赖倒置原则（Dependency Inversion Principle）

通过理解和运用这些面向对象编程的基本概念，我们可以设计出更加模块化、可维护和可扩展的程序。在实际开发中，需要根据具体场景选择合适的设计方式，平衡灵活性和复杂性。