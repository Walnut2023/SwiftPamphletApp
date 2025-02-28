# fishhook 动态符号替换工具

## 概述

fishhook 是 Facebook 开源的一个轻量级库，用于在 iOS/macOS 应用程序运行时动态替换 C 函数实现。它允许开发者拦截和修改系统库函数的调用，是性能分析和调试的强大工具。

## 工作原理

fishhook 利用了 Mach-O 二进制文件的动态链接机制，通过修改动态链接器的符号表（懒加载和非懒加载符号表）来实现函数替换。

### 核心原理

1. **Mach-O 文件结构**：iOS/macOS 应用使用 Mach-O 格式的二进制文件
2. **动态链接**：应用启动时，动态链接器会解析外部符号引用
3. **符号表修改**：fishhook 修改 `__DATA` 段中的 `__la_symbol_ptr`（懒加载）和 `__nl_symbol_ptr`（非懒加载）表

```c
struct rebinding {
    const char *name;     // 要替换的函数名
    void *replacement;    // 替换函数的实现
    void **replaced;      // 存储原始函数指针的地址
};
```

## 安装与配置

### 1. 通过 CocoaPods 集成

```ruby
pod 'fishhook'
```

### 2. 手动集成

1. 从 GitHub 下载 fishhook 源码：https://github.com/facebook/fishhook
2. 将 `fishhook.h` 和 `fishhook.c` 添加到项目中

## 使用方法

### 基本用法

```objc
#import "fishhook.h"
#include <sys/time.h>

// 定义替换函数
static int (*original_gettimeofday)(struct timeval *tv, struct timezone *tz);

// 自定义实现
static int my_gettimeofday(struct timeval *tv, struct timezone *tz) {
    // 在这里添加性能分析代码
    NSLog(@"gettimeofday 被调用");
    
    // 调用原始函数
    return original_gettimeofday(tv, tz);
}

// 替换函数
rebind_symbols((struct rebinding[1]){
    {"gettimeofday", my_gettimeofday, (void *)&original_gettimeofday}
}, 1);
```

### Swift 中使用

在 Swift 项目中使用 fishhook 需要创建 Objective-C 桥接文件：

```swift
// 在桥接头文件中导入
#import "fishhook.h"

// Swift 代码中使用
class FishHookManager {
    static func setupHooks() {
        // 在 Objective-C 文件中实现钩子逻辑
        FishHookHelper.setupHooks()
    }
}
```

## 性能分析应用场景

### 1. 网络请求监控

```objc
// 替换 NSURLSession 相关函数
static NSURLSession* (*original_URLSession)(id, SEL, NSURLSessionConfiguration*);

NSURLSession* swizzled_URLSession(id self, SEL _cmd, NSURLSessionConfiguration* configuration) {
    // 记录会话创建时间
    NSLog(@"创建 NSURLSession 实例");
    return original_URLSession(self, _cmd, configuration);
}

// 设置钩子
static void setupURLSessionHook() {
    Method originalMethod = class_getClassMethod(NSURLSession.class, @selector(sessionWithConfiguration:));
    original_URLSession = (void*)method_getImplementation(originalMethod);
    method_setImplementation(originalMethod, (IMP)swizzled_URLSession);
}
```

### 2. 文件操作性能分析

```objc
// 替换文件操作函数
static int (*original_open)(const char *, int, ...);
static ssize_t (*original_read)(int, void *, size_t);
static ssize_t (*original_write)(int, const void *, size_t);

int custom_open(const char *path, int oflag, ...) {
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    
    va_list args;
    va_start(args, oflag);
    mode_t mode = va_arg(args, int);
    va_end(args);
    
    int result = original_open(path, oflag, mode);
    
    NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970];
    NSLog(@"open(%s) 耗时: %.6f秒", path, endTime - startTime);
    
    return result;
}

// 设置钩子
rebind_symbols((struct rebinding[1]){
    {"open", custom_open, (void *)&original_open}
}, 1);
```

### 3. 内存分配监控

```objc
// 替换内存分配函数
static void* (*original_malloc)(size_t);
static void (*original_free)(void *);

void* custom_malloc(size_t size) {
    void *ptr = original_malloc(size);
    NSLog(@"malloc(%zu) = %p", size, ptr);
    return ptr;
}

void custom_free(void *ptr) {
    NSLog(@"free(%p)", ptr);
    original_free(ptr);
}

// 设置钩子
rebind_symbols((struct rebinding[2]){
    {"malloc", custom_malloc, (void *)&original_malloc},
    {"free", custom_free, (void *)&original_free}
}, 2);
```

## 高级应用

### 1. 构建性能分析框架

```objc
@interface PerformanceMonitor : NSObject

+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (void)stopMonitoring;
- (void)generateReport;

@end

@implementation PerformanceMonitor {
    NSMutableDictionary *_functionCalls;
    NSLock *_lock;
}

+ (instancetype)sharedInstance {
    static PerformanceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _functionCalls = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)recordCall:(const char *)functionName duration:(NSTimeInterval)duration {
    [_lock lock];
    NSString *name = @(functionName);
    NSMutableDictionary *info = _functionCalls[name];
    if (!info) {
        info = [@{
            @"count": @0,
            @"totalTime": @0.0,
            @"minTime": @(DBL_MAX),
            @"maxTime": @0.0
        } mutableCopy];
        _functionCalls[name] = info;
    }
    
    NSInteger count = [info[@"count"] integerValue] + 1;
    NSTimeInterval total = [info[@"totalTime"] doubleValue] + duration;
    NSTimeInterval min = MIN([info[@"minTime"] doubleValue], duration);
    NSTimeInterval max = MAX([info[@"maxTime"] doubleValue], duration);
    
    info[@"count"] = @(count);
    info[@"totalTime"] = @(total);
    info[@"minTime"] = @(min);
    info[@"maxTime"] = @(max);
    [_lock unlock];
}

- (void)generateReport {
    [_lock lock];
    NSLog(@"========== 性能分析报告 ==========");
    NSLog(@"函数名\t调用次数\t总时间(ms)\t平均时间(ms)\t最小时间(ms)\t最大时间(ms)");
    
    for (NSString *name in [_functionCalls keysSortedByValueWithOptions:0 
                           usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj2[@"totalTime"] compare:obj1[@"totalTime"]];
    }]) {
        NSDictionary *info = _functionCalls[name];
        NSInteger count = [info[@"count"] integerValue];
        NSTimeInterval total = [info[@"totalTime"] doubleValue] * 1000; // 转换为毫秒
        NSTimeInterval avg = total / count;
        NSTimeInterval min = [info[@"minTime"] doubleValue] * 1000;
        NSTimeInterval max = [info[@"maxTime"] doubleValue] * 1000;
        
        NSLog(@"%@\t%ld\t%.2f\t%.2f\t%.2f\t%.2f", 
              name, (long)count, total, avg, min, max);
    }
    NSLog(@"================================");
    [_lock unlock];
}

@end
```

### 2. 系统函数调用链分析

```objc
// 替换 objc_msgSend 进行方法调用分析
#if defined(__arm64__)
typedef id (*objc_msgSend_type)(id, SEL, ...);
static objc_msgSend_type original_objc_msgSend;

__attribute__((naked)) id custom_objc_msgSend(id self, SEL _cmd, ...) {
    // ARM64 汇编实现，记录方法调用
    __asm volatile (
        "stp x8, x9, [sp, #-16]!\n"
        "stp x6, x7, [sp, #-16]!\n"
        "stp x4, x5, [sp, #-16]!\n"
        "stp x2, x3, [sp, #-16]!\n"
        "stp x0, x1, [sp, #-16]!\n"
        // 调用记录函数
        "bl _record_objc_msgSend\n"
        "ldp x0, x1, [sp], #16\n"
        "ldp x2, x3, [sp], #16\n"
        "ldp x4, x5, [sp], #16\n"
        "ldp x6, x7, [sp], #16\n"
        "ldp x8, x9, [sp], #16\n"
        // 跳转到原始实现
        "b _original_objc_msgSend\n"
    );
}

void setup_objc_msgSend_hook(void) {
    original_objc_msgSend = (objc_msgSend_type)dlsym(RTLD_DEFAULT, "objc_msgSend");
    rebind_symbols((struct rebinding[1]){
        {"objc_msgSend", (void *)custom_objc_msgSend, (void **)&original_objc_msgSend}
    }, 1);
}
#endif
```

## 注意事项

1. **稳定性考虑**：替换系统函数可能导致应用不稳定，仅在开发和测试环境使用
2. **性能开销**：钩子函数会引入额外开销，影响测量结果的准确性
3. **兼容性**：不同iOS版本的系统库实现可能有差异
4. **App Store审核**：包含fishhook的应用可能不符合App Store审核要求

## 与其他工具的比较

| 工具 | 优点 | 缺点 |
|------|------|------|
| **fishhook** | 轻量级、易于集成、针对C函数 | 仅限C函数、需要源码修改 |
| **Method Swizzling** | 原生支持、针对Objective-C方法 | 不支持C函数、实现复杂 |
| **Frida** | 功能强大、无需修改源码 | 需要越狱设备、配置复杂 |
| **Instruments** | 官方工具、全面的性能分析 | 无法自定义分析逻辑 |

## 总结

fishhook 是一个强大的动态符号替换工具，特别适合iOS应用的性能分析和调试。通过替换系统函数，开发者可以监控和分析应用的各种行为，包括网络请求、文件操作和内存管理等。在开发和测试环境中，fishhook 是一个不可或缺的性能分析工具。

然而，由于其工作原理涉及修改运行时的符号表，在生产环境中使用需要谨慎。建议仅在开发和测试阶段使用，并在发布前移除相关代码。