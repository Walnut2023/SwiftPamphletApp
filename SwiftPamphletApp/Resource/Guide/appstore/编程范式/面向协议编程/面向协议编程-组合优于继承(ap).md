# 面向协议编程中的组合优于继承

在面向协议编程（POP）中，我们提倡使用协议组合而不是继承来构建代码。本文将通过一个具体的图形绘制系统案例来说明为什么组合优于继承，以及如何在Swift中实现这一原则。

## 传统继承方式的问题

让我们先看看使用继承方式实现图形系统可能遇到的问题：

```swift
class Shape {
    var color: UIColor
    
    init(color: UIColor) {
        self.color = color
    }
    
    func draw() {
        // 基础绘制逻辑
    }
}

class ShadowedShape: Shape {
    var shadowOffset: CGSize
    
    init(color: UIColor, shadowOffset: CGSize) {
        self.shadowOffset = shadowOffset
        super.init(color: color)
    }
    
    override func draw() {
        // 添加阴影的绘制逻辑
        super.draw()
    }
}

class AnimatedShape: Shape {
    var duration: TimeInterval
    
    init(color: UIColor, duration: TimeInterval) {
        self.duration = duration
        super.init(color: color)
    }
    
    override func draw() {
        // 添加动画的绘制逻辑
        super.draw()
    }
}
```

这种继承方式存在以下问题：

1. **组合爆炸**：如果我们想要一个既有阴影又能动画的形状，就需要创建新的`AnimatedShadowedShape`类
2. **继承链过长**：随着特性增加，继承链会变得越来越长
3. **代码重复**：不同分支的相同功能需要重复实现
4. **灵活性差**：难以在运行时动态组合功能

## 使用协议组合的解决方案

现在让我们看看如何使用协议组合来重构这个系统：

```swift
// 基本绘制协议
protocol Drawable {
    var color: UIColor { get set }
    func draw()
}

// 阴影特性协议
protocol Shadowable {
    var shadowOffset: CGSize { get set }
    func applyShadow()
}

// 动画特性协议
protocol Animatable {
    var duration: TimeInterval { get set }
    func animate()
}

// 使用协议扩展提供默认实现
extension Shadowable {
    func applyShadow() {
        // 默认阴影实现
        print("应用阴影效果，偏移量：\(shadowOffset)")
    }
}

extension Animatable {
    func animate() {
        // 默认动画实现
        print("执行动画，持续时间：\(duration)秒")
    }
}

// 具体的形状实现
struct Circle: Drawable {
    var color: UIColor
    
    func draw() {
        print("绘制\(color)颜色的圆形")
    }
}

// 组合多个特性
struct AnimatedCircle: Drawable, Animatable {
    var color: UIColor
    var duration: TimeInterval
    
    func draw() {
        print("绘制\(color)颜色的圆形")
        animate()
    }
}

// 灵活组合所有特性
struct ComplexShape: Drawable, Shadowable, Animatable {
    var color: UIColor
    var shadowOffset: CGSize
    var duration: TimeInterval
    
    func draw() {
        print("绘制\(color)颜色的复杂形状")
        applyShadow()
        animate()
    }
}
```

## 协议组合的优势

1. **更好的组合性**
   - 可以根据需要自由组合不同特性
   - 避免了继承层次的复杂性
   - 更容易添加新功能

2. **代码复用**
   - 通过协议扩展提供默认实现
   - 可以选择性地覆盖默认实现
   - 避免代码重复

3. **更好的可测试性**
   - 每个协议都可以独立测试
   - 更容易创建测试替身
   - 更清晰的依赖关系

4. **运行时灵活性**
   - 可以动态组合不同特性
   - 更容易适应需求变化

## 实际应用示例

```swift
// 创建不同类型的形状
let simpleCircle = Circle(color: .red)
let animatedCircle = AnimatedCircle(color: .blue, duration: 2.0)
let complexShape = ComplexShape(
    color: .green,
    shadowOffset: CGSize(width: 2, height: 2),
    duration: 1.5
)

// 使用泛型和协议组合
func renderShape<T: Drawable & Shadowable>(_ shape: T) {
    shape.draw()
    shape.applyShadow()
}

// 使用协议组合作为类型约束
func animateShape<T: Drawable & Animatable>(_ shape: T) {
    shape.draw()
    shape.animate()
}
```

## 最佳实践

1. **保持协议简单**
   - 每个协议专注于单一功能
   - 避免创建过于庞大的协议

2. **善用协议扩展**
   - 提供默认实现减少重复代码
   - 根据需要覆盖默认实现

3. **组合而非继承**
   - 优先考虑协议组合
   - 只在确实需要时使用继承

4. **注意性能影响**
   - 协议组合通常会带来更好的性能（静态派发）
   - 避免过度使用@objc协议

通过这个图形系统的例子，我们可以清楚地看到协议组合相比继承具有更好的灵活性和可维护性。在Swift中，我们应该优先考虑使用协议组合来构建功能，这样可以获得更清晰、更灵活的代码结构。