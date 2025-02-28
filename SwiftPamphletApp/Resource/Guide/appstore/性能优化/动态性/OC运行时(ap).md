# OC运行时

## 概述

Objective-C 运行时是一个运行时系统，它为 Objective-C 提供了动态特性，使其区别于静态语言。这个运行时系统实现了对象创建、方法调度、消息传递等核心功能，是 Objective-C 面向对象特性的基础。

## 核心特性

### 动态消息分发

```objective-c
// 消息发送的本质
[object method:parameter];

// 实际上会被编译器转换为
id result = objc_msgSend(object, @selector(method:), parameter);
```

消息分发过程：
1. 在对象的类中查找方法实现
2. 如果没找到，沿着继承链向上查找
3. 如果仍未找到，进入动态方法解析阶段
4. 如果动态方法解析失败，进入消息转发阶段

### 方法交换 (Method Swizzling)

```objective-c
#import <objc/runtime.h>

@implementation UIViewController (Tracking)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(xxx_viewDidAppear:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class,
                                           originalSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                               swizzledSelector,
                               method_getImplementation(originalMethod),
                               method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)xxx_viewDidAppear:(BOOL)animated {
    [self xxx_viewDidAppear:animated];
    NSLog(@"视图已显示: %@", self);
}

@end
```

### 关联对象 (Associated Objects)

```objective-c
#import <objc/runtime.h>

@implementation UIView (Badge)

static char badgeValueKey;

- (void)setBadgeValue:(NSString *)badgeValue {
    objc_setAssociatedObject(self, &badgeValueKey, badgeValue, OBJC_ASSOCIATION_COPY_NONATOMIC);
    // 更新徽章显示
}

- (NSString *)badgeValue {
    return objc_getAssociatedObject(self, &badgeValueKey);
}

@end
```

### 类型编码与反射

```objective-c
// 获取类的所有属性
id class = [MyClass class];
unsigned int count;
objc_property_t *properties = class_copyPropertyList(class, &count);

for (int i = 0; i < count; i++) {
    objc_property_t property = properties[i];
    const char *name = property_getName(property);
    const char *attributes = property_getAttributes(property);
    NSLog(@"属性名: %s, 属性特性: %s", name, attributes);
}

free(properties);
```

## 应用场景

### 1. 埋点与性能监控

通过方法交换，可以在不侵入原有代码的情况下，为关键方法添加性能监控或数据埋点。

```objective-c
// 监控视图控制器生命周期
+ (void)load {
    [self swizzleMethod:@selector(viewDidLoad) withMethod:@selector(tracked_viewDidLoad)];
}

- (void)tracked_viewDidLoad {
    NSTimeInterval startTime = CACurrentMediaTime();
    [self tracked_viewDidLoad]; // 调用原方法
    NSTimeInterval endTime = CACurrentMediaTime();
    
    // 记录加载时间
    NSLog(@"%@ 加载耗时: %f秒", NSStringFromClass([self class]), endTime - startTime);
}
```

### 2. 动态创建类和对象

```objective-c
// 动态创建类
Class newClass = objc_allocateClassPair([NSObject class], "DynamicClass", 0);

// 添加实例变量
class_addIvar(newClass, "_dynamicVar", sizeof(NSString *), log2(sizeof(NSString *)), @encode(NSString *));

// 添加方法
class_addMethod(newClass, @selector(dynamicMethod), (IMP)dynamicMethodIMP, "v@:");

// 注册类
objc_registerClassPair(newClass);

// 创建实例
id instance = [[newClass alloc] init];
```

### 3. 模型与JSON转换

利用运行时反射机制，可以实现自动的JSON到模型对象的转换。

```objective-c
+ (instancetype)modelWithJSON:(NSDictionary *)json {
    id model = [[self alloc] init];
    
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString *name = @(property_getName(property));
        id value = json[name];
        
        if (value) {
            [model setValue:value forKey:name];
        }
    }
    
    free(properties);
    return model;
}
```

## 性能考量

虽然OC运行时提供了强大的动态特性，但也带来了性能开销：

1. **消息分发开销**：动态消息分发比直接函数调用慢
2. **方法缓存**：运行时系统通过缓存来优化消息分发
3. **内存占用**：运行时元数据会增加内存占用

## 最佳实践

1. **谨慎使用方法交换**：只在必要时使用，避免过度使用导致代码难以理解和维护
2. **注意线程安全**：运行时操作通常不是线程安全的，需要适当同步
3. **在+load方法中进行方法交换**：确保在类加载时完成，避免竞态条件
4. **避免滥用关联对象**：过多使用会导致内存管理复杂化
5. **考虑性能影响**：在性能敏感的代码路径上避免过度依赖运行时特性

## 与Swift的比较

Objective-C运行时提供了极高的灵活性，但也带来了安全性和性能方面的挑战。Swift采用了更静态的类型系统，减少了运行时决策，提高了类型安全性和性能，但也限制了一些动态特性。

在混编项目中，了解两种语言的运行时特性及其差异，对于优化应用性能和解决互操作问题至关重要。