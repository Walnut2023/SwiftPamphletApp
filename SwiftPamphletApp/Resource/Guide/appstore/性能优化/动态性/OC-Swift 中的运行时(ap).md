# OC-Swift 中的运行时

## 概述

在混编项目中，Objective-C 和 Swift 两种语言需要通过各自的运行时系统进行交互。这种交互是通过桥接技术实现的，允许两种语言的代码相互调用和共享数据。理解这种运行时交互机制对于优化混编项目的性能至关重要。

## 桥接原理

### Swift调用Objective-C

当Swift代码调用Objective-C代码时，Swift编译器会生成必要的桥接代码，将Swift的方法调用转换为Objective-C的消息发送。

```swift
// Swift代码
import UIKit

class MyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad() // 调用OC方法
        
        // 使用OC类
        let alert = UIAlertController(title: "标题", message: "消息", preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }
}
```

### Objective-C调用Swift

当Objective-C代码调用Swift代码时，需要通过生成的头文件（项目名-Swift.h）来访问Swift类和方法。

```objective-c
// Objective-C代码
#import "MyProject-Swift.h" // 自动生成的头文件

@implementation MyObjCClass

- (void)useSwiftClass {
    // 使用Swift类
    MySwiftClass *swiftObject = [[MySwiftClass alloc] init];
    [swiftObject swiftMethod];
}

@end
```

## 类型映射

### 基本类型映射

| Swift类型 | Objective-C类型 |
|-----------|----------------|
| Int, Float, Double | NSNumber |
| String | NSString |
| Array<Element> | NSArray |
| Dictionary<Key, Value> | NSDictionary |
| Set<Element> | NSSet |

### 复杂类型映射

```swift
// Swift中定义的类
@objc class Person: NSObject {
    @objc var name: String
    @objc var age: Int
    
    @objc init(name: String, age: Int) {
        self.name = name
        self.age = age
        super.init()
    }
    
    @objc func introduce() -> String {
        return "我是\(name), \(age)岁"
    }
}
```

```objective-c
// Objective-C中使用Swift类
Person *person = [[Person alloc] initWithName:@"张三" age:30];
NSString *intro = [person introduce];
NSLog(@"%@", intro);
```

## 运行时交互机制

### @objc 和 dynamic 关键字

```swift
// @objc 使Swift方法和属性对Objective-C可见
@objc class MyClass: NSObject {
    // dynamic 使用OC运行时动态分发
    @objc dynamic var property: String = "值"
    
    @objc func method() {
        print("方法被调用")
    }
}
```

### 方法交换在混编环境中的应用

```swift
// Swift中使用OC运行时进行方法交换
extension UIViewController {
    static func setupMethodSwizzling() {
        // 确保代码只执行一次
        DispatchQueue.once(token: "com.app.methodSwizzling") {
            let originalSelector = #selector(viewWillAppear(_:))
            let swizzledSelector = #selector(swizzled_viewWillAppear(_:))
            
            guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
                  let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
                return
            }
            
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc func swizzled_viewWillAppear(_ animated: Bool) {
        // 调用原始实现
        self.swizzled_viewWillAppear(animated)
        
        // 添加额外行为
        print("视图将要出现: \(type(of: self))")
    }
}

// 扩展DispatchQueue以支持只执行一次的操作
extension DispatchQueue {
    private static var onceTokens = [String: Bool]()
    private static let onceTokensLock = NSLock()
    
    static func once(token: String, block: () -> Void) {
        onceTokensLock.lock()
        defer { onceTokensLock.unlock() }
        
        if onceTokens[token] == nil {
            onceTokens[token] = true
            block()
        }
    }
}
```

## 性能优化策略

### 1. 减少跨语言调用

频繁的跨语言调用会带来性能开销，应尽量在同一语言环境中完成相关功能。

```swift
// 不推荐：频繁跨语言调用
for i in 0..<1000 {
    let ocObject = MyObjCClass()
    ocObject.process(i)
}

// 推荐：批量处理后再跨语言调用
let data = Array(0..<1000)
let ocProcessor = MyObjCClass()
ocProcessor.processItems(data)
```

### 2. 合理使用 @objc 标记

只为需要暴露给Objective-C的方法和属性添加 @objc 标记，避免不必要的桥接开销。

```swift
class MySwiftClass: NSObject {
    // 只有需要OC访问的方法才标记@objc
    @objc func methodForObjC() {
        // 可被OC调用
    }
    
    func swiftOnlyMethod() {
        // 仅Swift内部使用，无桥接开销
    }
}
```

### 3. 使用值类型优化

在Swift中优先使用值类型（结构体、枚举）而非引用类型（类），可以减少引用计数开销。

```swift
// 使用结构体代替类
struct UserProfile {
    let id: Int
    let name: String
    let preferences: [String: Bool]
}

// 只在需要OC交互的地方使用类
@objc class UserProfileObjC: NSObject {
    @objc let id: Int
    @objc let name: String
    
    init(profile: UserProfile) {
        self.id = profile.id
        self.name = profile.name
        super.init()
    }
}
```

### 4. 避免不必要的动态特性

```swift
// 避免过度使用dynamic
class MyClass {
    // 不需要动态分发的属性
    var normalProperty: String = ""
    
    // 只有需要KVO或方法交换的属性才使用dynamic
    @objc dynamic var observableProperty: String = ""
}
```

## 实际案例分析

### 启动优化中的运行时应用

在SwiftTestApp项目中，可以看到混编环境下的启动优化示例：

```swift
// 在AppDelegate中初始化时进行运行时操作
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 设置方法交换以监控关键方法执行时间
    UIViewController.setupMethodSwizzling()
    
    // 延迟加载非关键功能
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.setupNonCriticalFeatures()
    }
    
    return true
}
```

### 性能监控实现

结合OC运行时和Swift Concurrency实现性能监控：

```swift
// 混合使用OC运行时和Swift并发特性进行性能监控
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    func setupMonitoring() {
        // 使用OC运行时监控关键方法
        setupMethodSwizzling()
        
        // 使用Swift并发特性处理监控数据
        Task {
            await processPerformanceData()
        }
    }
    
    private func setupMethodSwizzling() {
        // 实现方法交换逻辑
    }
    
    private func processPerformanceData() async {
        // 使用Swift并发处理收集的性能数据
    }
}
```

## 最佳实践

1. **明确语言边界**：清晰划分Swift和Objective-C代码的职责，减少不必要的跨语言调用
2. **合理使用标记**：只为必要的成员添加@objc和dynamic标记
3. **优化数据传递**：在语言边界传递数据时，考虑批量传递而非频繁小数据传递
4. **利用Swift优势**：在Swift代码中充分利用值类型、泛型和编译时优化
5. **保持更新**：随着Swift语言的发展，逐步减少对Objective-C运行时的依赖

## 结论

在混编项目中，理解OC和Swift运行时的交互机制对于编写高效、可维护的代码至关重要。通过合理设计语言边界、优化跨语言调用，可以在保持代码灵活性的同时，最大限度地提高应用性能。随着项目逐步向纯Swift迁移，可以更多地利用Swift的静态特性和编译优化，进一步提升应用性能。
