# Swift无用代码

## 概述

无用代码（Dead Code）是指那些永远不会被执行的代码，它们占用了宝贵的包体积空间却不提供任何功能价值。在Swift项目中，识别和移除无用代码是减小应用体积的有效方法。本文介绍SwiftTestApp在处理Swift无用代码方面的实践经验。

## 无用代码的类型

### 1. 未使用的函数和方法

- 定义但从未被调用的函数
- 被注释掉但未删除的代码
- 条件永远为假的代码分支

### 2. 未使用的类和结构体

- 定义但从未实例化的类
- 被其他类替代但未删除的旧类

### 3. 未使用的资源和资产

- 代码中不再引用的图片、音频等资源
- 过时的本地化字符串

### 4. 调试和测试代码

- 发布版本中的调试日志
- 仅用于测试的辅助函数

## 检测工具

### 1. Periphery

[Periphery](https://github.com/peripheryapp/periphery)是专为Swift项目设计的无用代码检测工具，能够识别未使用的类、方法、属性等。

```bash
# 安装Periphery
brew install periphery

# 基本使用
periphery scan --workspace SwiftTestApp.xcworkspace --schemes SwiftTestApp

# 生成HTML报告
periphery scan --workspace SwiftTestApp.xcworkspace --schemes SwiftTestApp --format html --output deadcode-report.html
```

- SwiftTestApp实践：使用Periphery检测出约2.5MB的无用代码，主要集中在早期开发阶段遗留的实验性功能

### 2. Xcode的编译器警告

启用Xcode中的未使用代码警告：

- Build Settings > Swift Compiler - Warnings > Unused code > Yes
- 添加编译标志`-Wunused-function`和`-Wunused-variable`

### 3. AppCode的代码检查

JetBrains的AppCode提供了更强大的代码检查功能，可以检测：

- 未使用的导入
- 未使用的方法参数
- 未使用的局部变量
- 永远不会执行的代码

## 手动检测技术

### 1. 符号引用分析

使用`nm`命令分析二进制文件中的符号：

```bash
# 查看所有符号
nm -nm SwiftTestApp | grep "__T"

# 查找未引用的符号
otool -l SwiftTestApp | grep -A2 "__objc_classrefs"
```

### 2. 代码覆盖率分析

使用Xcode的代码覆盖率工具识别未执行的代码：

1. Edit Scheme > Test > Options > Code Coverage > Enable Code Coverage
2. 运行测试后查看覆盖率报告
3. 长期未被测试覆盖的代码可能是无用代码

## 移除策略

### 1. 渐进式移除

- 不要一次性删除所有检测到的无用代码
- 按模块分批移除，每次移除后进行完整测试
- SwiftTestApp实践：我们采用了四周期的移除计划，每周移除一个主要模块中的无用代码

### 2. 特性标记法

对于不确定是否使用的代码：

```swift
// 标记可能废弃的代码
@available(*, deprecated, message: "计划在v2.5移除，如有使用请联系开发团队")
func legacyFunction() {
    // 实现
}
```

- 监控一段时间（如3个月）内是否有调用
- 使用日志或分析工具跟踪使用情况

### 3. 条件编译

对于仅在特定环境使用的代码，使用条件编译而非删除：

```swift
#if DEBUG
func debugOnlyFunction() {
    // 调试用代码
}
#endif

#if targetEnvironment(simulator)
// 仅模拟器使用的代码
#endif
```

## 预防措施

### 1. 代码审查流程

- 在代码审查中关注无用代码的引入
- 要求提交者解释每个新增函数的用途

### 2. 定期扫描

- 在CI流程中集成无用代码检测
- 每月进行一次全面的无用代码扫描

```yaml
# GitHub Actions工作流示例
detect-dead-code:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v2
    - name: Install Periphery
      run: brew install periphery
    - name: Scan for dead code
      run: periphery scan --workspace SwiftTestApp.xcworkspace --schemes SwiftTestApp --format xcode
    - name: Check results
      run: |
        if [ -s periphery-results.txt ]; then
          echo "::warning::Dead code detected! Check periphery-results.txt"
        fi
```

### 3. 功能切换系统

- 实现功能标志系统，便于安全地移除过时功能
- 使用远程配置控制功能的启用/禁用

## 实际效果

SwiftTestApp无用代码移除效果：

| 代码类型 | 移除行数 | 减少体积 | 占总优化比例 |
|---------|--------|---------|------------|
| 未使用的类和结构体 | 4,200行 | 1.8MB | 45% |
| 废弃的功能代码 | 2,800行 | 1.2MB | 30% |
| 调试和测试代码 | 1,500行 | 0.6MB | 15% |
| 重复代码 | 1,000行 | 0.4MB | 10% |
| 总计 | 9,500行 | 4.0MB | 100% |

## 最佳实践

1. **建立"零无用代码"文化**，鼓励开发者主动清理
2. **实现功能切换机制**，安全地废弃旧功能
3. **使用自动化工具**定期检测无用代码
4. **在代码审查中关注**无用代码的引入
5. **记录重要决策**，说明为何保留看似未使用的代码

## 结论

无用代码清理是一项持续性工作，需要工具支持和团队共识。通过系统性地识别和移除无用代码，SwiftTestApp成功减少了4MB的应用体积，同时提高了代码的可维护性和编译速度。建立预防机制比事后清理更为重要，应将无用代码检测融入日常开发流程中。