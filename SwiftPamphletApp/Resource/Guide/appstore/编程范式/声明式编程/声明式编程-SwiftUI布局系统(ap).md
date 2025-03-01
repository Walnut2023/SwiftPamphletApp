# SwiftUI布局系统

## 布局系统概述

SwiftUI的布局系统是完全声明式的，它通过一系列简单的规则来确定视图的大小和位置。布局系统的核心是父视图向子视图提供建议的大小，子视图决定自己的大小，然后父视图负责放置子视图。

## 布局原理

### 1. 布局过程
```swift
// 布局过程的三个步骤
struct MyView: View {
    var body: some View {
        HStack(spacing: 10) { // 1. 父视图提供建议大小
            Text("Hello") // 2. 子视图决定自己的大小
            Circle() // 3. 父视图放置子视图
                .frame(width: 50, height: 50)
        }
        .padding()
    }
}
```

### 2. 布局优先级
```swift
HStack {
    Text("固定宽度")
        .frame(width: 100)
        .layoutPriority(1)
    
    Text("自适应宽度，较低优先级")
        .layoutPriority(0)
}
```

## 常用布局容器

### 1. Stack系列
```swift
// 垂直堆栈
VStack(alignment: .leading, spacing: 10) {
    Text("标题")
        .font(.title)
    Text("副标题")
        .font(.subheadline)
}

// 水平堆栈
HStack {
    Image(systemName: "star.fill")
    Text("评分")
}

// 深度堆栈
ZStack {
    Color.blue
    Text("覆盖在蓝色背景上")
}
```

### 2. Grid布局
```swift
Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
    GridRow {
        Text("A1")
        Text("B1")
    }
    GridRow {
        Text("A2")
        Text("B2")
    }
}
```

### 3. LazyStack和LazyGrid
```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
}

LazyVGrid(columns: [
    GridItem(.flexible()),
    GridItem(.flexible())
]) {
    ForEach(items) { item in
        ItemView(item: item)
    }
}
```

## 自定义布局

### 1. 使用GeometryReader
```swift
GeometryReader { geometry in
    HStack(spacing: 0) {
        Rectangle()
            .fill(Color.red)
            .frame(width: geometry.size.width * 0.3)
        Rectangle()
            .fill(Color.blue)
            .frame(width: geometry.size.width * 0.7)
    }
}
```

### 2. 自定义Layout协议
```swift
struct CustomLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // 计算布局大小
        return CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        // 放置子视图
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + CGFloat(index) * 50,
                               y: bounds.minY)
            subview.place(at: point, proposal: proposal)
        }
    }
}
```

## 布局修饰符

### 1. 尺寸修饰符
```swift
Text("调整大小")
    .frame(width: 200, height: 100)
    .fixedSize(horizontal: true, vertical: false)
    .minimumScaleFactor(0.5)
```

### 2. 位置修饰符
```swift
Text("位置调整")
    .position(x: 100, y: 100)
    .offset(x: 20, y: 20)
```

### 3. 对齐修饰符
```swift
HStack(alignment: .firstTextBaseline) {
    Text("基线对齐")
        .font(.largeTitle)
    Text("小字体")
        .font(.caption)
}
```

## 最佳实践

1. **选择合适的布局容器**
   - 使用正确的Stack类型
   - 需要滚动时使用LazyStack
   - 网格布局使用Grid或LazyGrid

2. **性能优化**
   - 避免过深的视图层级
   - 合理使用LazyStack和LazyGrid
   - 适当使用Group组织视图

3. **响应式布局**
```swift
@Environment(\.horizontalSizeClass) var sizeClass

var body: some View {
    if sizeClass == .compact {
        VStack { content }
    } else {
        HStack { content }
    }
}
```

4. **可访问性**
```swift
Text("标签")
    .accessibilityLabel("自定义标签")
    .accessibilityHint("点击查看详情")
```

## 总结

SwiftUI的布局系统通过声明式的方式，提供了强大而灵活的布局能力。通过理解布局原理，合理使用布局容器和修饰符，我们可以创建出适应性强、性能好的用户界面。在实际开发中，应该根据具体需求选择合适的布局方案，并注意遵循最佳实践。