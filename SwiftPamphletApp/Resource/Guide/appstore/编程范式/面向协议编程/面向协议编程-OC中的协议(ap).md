# Objective-C中的协议实现

本文将介绍Objective-C中协议（Protocol）的实现特点和最佳实践。

## 基本概念

### 1. 协议声明

```objc
@protocol DataProviding <NSObject>

@required
- (NSArray *)fetchData;
- (void)saveData:(NSArray *)data;

@optional
- (void)dataDidUpdate;

@end
```

### 2. 协议实现

```objc
@interface DataManager : NSObject <DataProviding>
@end

@implementation DataManager

- (NSArray *)fetchData {
    // 实现获取数据的逻辑
    return @[];
}

- (void)saveData:(NSArray *)data {
    // 实现保存数据的逻辑
}

@end
```

## 协议的特点

1. **必选和可选方法**
   - @required：必须实现的方法
   - @optional：可选实现的方法

2. **协议继承**

```objc
@protocol AdvancedDataProviding <DataProviding>
- (void)processData:(NSArray *)data;
@end
```

3. **协议组合**

```objc
@interface DataProcessor : NSObject <DataProviding, NSCopying>
@end
```

## 常见应用场景

### 1. 代理模式

```objc
@protocol DataManagerDelegate <NSObject>
@optional
- (void)dataManager:(DataManager *)manager didUpdateData:(NSArray *)data;
- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error;
@end

@interface DataManager : NSObject
@property (weak, nonatomic) id<DataManagerDelegate> delegate;
@end
```

### 2. 数据源

```objc
@protocol TableViewDataSource <NSObject>
@required
- (NSInteger)numberOfRows;
- (UITableViewCell *)cellForRowAtIndex:(NSInteger)index;
@end
```

## 最佳实践

1. **命名规范**

```objc
// 使用描述性的名称
@protocol UserAuthenticating <NSObject>
- (void)authenticateUser:(User *)user completion:(void(^)(BOOL success))completion;
@end
```

2. **错误处理**

```objc
@protocol NetworkService <NSObject>
- (void)fetchDataWithCompletion:(void(^)(id data, NSError *error))completion;
@end
```

3. **类型检查**

```objc
if ([object conformsToProtocol:@protocol(DataProviding)]) {
      id<DataProviding> provider = (id<DataProviding>)object;
      [provider fetchData];
}
```

## 与Swift的区别

1. **语法差异**
   - OC使用@protocol声明
   - OC需要显式声明可选方法
   - OC不支持协议扩展

2. **功能限制**

```objc
// OC中不支持默认实现
@protocol Drawable <NSObject>
@required
- (void)draw; // 无法提供默认实现
@end
```

3. **类型系统**
   - OC的协议主要用于引用类型
   - 不支持关联类型
   - 不支持协议约束

## 实际应用示例

### 1. 网络层抽象

```objc
@protocol NetworkRequestable <NSObject>

@required
- (void)executeRequest:(NSURLRequest *)request
            completion:(void(^)(NSData *data, NSError *error))completion;

@optional
- (void)cancelRequest;
- (void)setupConfiguration:(NSDictionary *)config;

@end

@interface NetworkManager : NSObject <NetworkRequestable>
@end

@implementation NetworkManager

- (void)executeRequest:(NSURLRequest *)request
            completion:(void(^)(NSData *data, NSError *error))completion {
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion) {
            completion(data, error);
        }
    }];
    [task resume];
}

@end
```

### 2. UI组件抽象

```objc
@protocol Configurable <NSObject>

@required
- (void)configureWithModel:(id)model;

@optional
- (void)prepareForReuse;

@end

@interface CustomCell : UITableViewCell <Configurable>
@end

@implementation CustomCell

- (void)configureWithModel:(id)model {
    // 配置cell的UI
}

- (void)prepareForReuse {
    // 重置cell的状态
}

@end
```

## 注意事项

1. **内存管理**
   - 代理属性通常声明为weak，避免循环引用
   - 注意block中的循环引用问题

2. **方法检查**

```objc
if ([self.delegate respondsToSelector:@selector(dataDidUpdate)]) {
      [self.delegate dataDidUpdate];
}
```

3. **多协议遵守**

```objc
@interface ComplexManager : NSObject 
    <NetworkRequestable,
      DataProviding,
      UITableViewDataSource>
@end
```

通过合理使用Objective-C的协议特性，我们可以：

- 实现松耦合的设计
- 提供清晰的接口定义
- 支持代理模式和数据源模式
- 实现基本的多态性

虽然相比Swift的协议系统功能较少，但Objective-C的协议仍然是一个强大的工具，特别是在处理代理模式和定义接口约定时。在实际开发中，应该根据具体需求选择合适的设计方案，合理利用协议的特性。
