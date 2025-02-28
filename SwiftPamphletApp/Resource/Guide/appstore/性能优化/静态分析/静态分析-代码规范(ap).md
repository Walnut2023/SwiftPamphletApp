# 静态分析-代码规范

## 简介

代码规范是保证代码质量和可维护性的重要基础。通过静态分析工具，我们可以自动化地检查代码是否符合规范，及早发现潜在问题。本文将介绍Swift项目中常用的代码规范检查工具和实践经验。

## 常用工具

### SwiftLint

#### 基本配置

在项目根目录创建 `.swiftlint.yml` 配置文件：

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - missing_docs
  - closure_spacing

type_name:
  min_length: 3
  max_length:
    warning: 40
    error: 50

function_parameter_count:
  warning: 6
  error: 8

cyclomatic_complexity:
  warning: 10
  error: 20

file_length:
  warning: 400
  error: 1000

type_body_length:
  warning: 300
  error: 500
```

#### 自定义规则

```yaml
custom_rules:
  image_name_rule:
    name: "Image Name Rule"
    regex: 'UIImage\(named: "([^"]*)"\)'
    message: "Image literals are preferred over string literals"
    severity: warning

  custom_logger:
    name: "Custom Logger Rule"
    regex: 'print\(.*\)'
    message: "Use custom logger instead of print"
    severity: warning
```

### 实际应用案例

#### 命名规范检查

```swift
// 违反规范的代码
class vc: UIViewController { // 违反类名规范
    var x: Int = 0 // 违反变量命名规范
    
    func btn_click() { // 违反函数命名规范
        // ...
    }
}

// 符合规范的代码
class ProfileViewController: UIViewController {
    var userAge: Int = 0
    
    func handleButtonTap() {
        // ...
    }
}
```

#### 复杂度控制

```swift
// 违反复杂度规范的代码
func processUserData(_ data: [String: Any]) -> Bool {
    if let name = data["name"] as? String {
        if name.count > 0 {
            if let age = data["age"] as? Int {
                if age >= 18 {
                    if let email = data["email"] as? String {
                        if email.contains("@") {
                            // 过多的嵌套导致高圈复杂度
                            return true
                        }
                    }
                }
            }
        }
    }
    return false
}

// 优化后的代码
func processUserData(_ data: [String: Any]) -> Bool {
    guard let name = data["name"] as? String,
          !name.isEmpty,
          let age = data["age"] as? Int,
          age >= 18,
          let email = data["email"] as? String,
          email.contains("@") else {
        return false
    }
    return true
}
```

#### 文档注释规范

```swift
// 违反文档规范的代码
func calculateTotal(items: [Item]) -> Double {
    return items.reduce(0) { $0 + $1.price }
}

// 符合文档规范的代码
/// 计算商品总价
/// - Parameter items: 商品列表
/// - Returns: 总价（元）
/// - Note: 不包含折扣计算
func calculateTotal(items: [Item]) -> Double {
    return items.reduce(0) { $0 + $1.price }
}
```

### 自动化集成

#### Xcode集成

在Build Phases中添加SwiftLint检查：

```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

#### CI/CD集成

```yaml
# .github/workflows/swiftlint.yml
name: SwiftLint

on:
  pull_request:
    paths:
      - '.github/workflows/swiftlint.yml'
      - '.swiftlint.yml'
      - '**/*.swift'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run SwiftLint
        uses: norio-nomura/action-swiftlint@3.2.1
        with:
          args: --strict
```

## 最佳实践

### 渐进式规范应用

1. 从基础规则开始
```yaml
# 初始阶段的.swiftlint.yml
only_rules:
  - trailing_semicolon
  - force_cast
  - force_try
  - force_unwrapping
```

2. 逐步增加规则
```yaml
# 进阶阶段的规则
opt_in_rules:
  - empty_count
  - closure_spacing
  - explicit_init
  - redundant_nil_coalescing
```

### 团队协作

1. 统一配置文件
2. 代码审查清单
3. 定期规范评审

### 性能考虑

1. 选择性规则启用
2. 增量检查策略
3. 缓存优化

## 工具链集成

### 编辑器插件

1. VSCode插件配置
```json
{
    "editor.formatOnSave": true,
    "swift.swiftLint.enable": true,
    "swift.swiftLint.configFile": ".swiftlint.yml"
}
```

2. Xcode Source Editor Extension

### Git Hooks

```bash
#!/bin/sh
# .git/hooks/pre-commit

files=$(git diff --cached --name-only | grep ".swift$")
if [ -n "$files" ]; then
    swiftlint lint --path "$files" --strict
    if [ $? -ne 0 ]; then
        echo "SwiftLint failed"
        exit 1
    fi
fi
```

## 常见问题解决

### 规则冲突

```yaml
# 处理规则冲突
disabled_rules:
  - multiple_closures_with_trailing_closure # 与SwiftUI视图构建冲突
  - identifier_name # 与某些设计模式命名冲突

# 为特定文件禁用规则
excluded:
  - Pods
  - Generated
  - UITests
```

### 性能优化

1. 使用缓存
2. 增量检查
3. 并行处理

## 总结

代码规范的静态分析是提高代码质量的重要手段。通过合理配置工具、制定规范策略、自动化集成，我们可以在开发过程中持续保持代码质量。结合实际案例和最佳实践，团队可以逐步建立起适合自己的代码规范体系。