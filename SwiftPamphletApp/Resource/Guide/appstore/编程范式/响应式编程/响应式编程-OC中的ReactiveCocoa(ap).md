# ReactiveCocoa框架

## 简介

ReactiveCocoa (RAC) 是一个为Objective-C设计的响应式编程框架，它将函数式编程的思想引入到Cocoa开发中。

## 核心概念

### 1. 信号 (RACSignal)
```objectivec
// 创建信号
RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
    [subscriber sendNext:@"Hello RAC"];
    [subscriber sendCompleted];
    return nil;
}];

// 订阅信号
[signal subscribeNext:^(id x) {
    NSLog(@"收到数据：%@", x);
}];
```

### 2. 序列 (RACSequence)
```objectivec
// 数组转换为序列
NSArray *numbers = @[@1, @2, @3];
RACSequence *sequence = numbers.rac_sequence;
RACSignal *signal = sequence.signal;

[signal subscribeNext:^(id x) {
    NSLog(@"数字：%@", x);
}];
```

### 3. 命令 (RACCommand)
```objectivec
// 创建命令
RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        // 执行异步操作
        [subscriber sendNext:@"操作完成"];
        [subscriber sendCompleted];
        return nil;
    }];
}];

// 执行命令
[command execute:nil];
```

## 实际应用

### 1. UI绑定
```objectivec
// 双向绑定
@interface LoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 绑定输入框
    RAC(self.viewModel, username) = self.usernameField.rac_textSignal;
    RAC(self.viewModel, password) = self.passwordField.rac_textSignal;
    
    // 绑定按钮状态
    RAC(self.loginButton, enabled) = [RACSignal
        combineLatest:@[RACObserve(self.viewModel, username),
                       RACObserve(self.viewModel, password)]
        reduce:^(NSString *username, NSString *password) {
            return @(username.length > 0 && password.length > 0);
        }];
}

@end
```

### 2. 网络请求
```objectivec
// 封装网络请求
@interface NetworkService : NSObject
+ (RACSignal *)fetchUserWithID:(NSString *)userID;
@end

@implementation NetworkService

+ (RACSignal *)fetchUserWithID:(NSString *)userID {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSURLSession *session = [NSURLSession sharedSession];
        NSString *urlString = [NSString stringWithFormat:@"https://api.example.com/users/%@", userID];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSURLSessionDataTask *task = [session dataTaskWithURL:url
                                            completionHandler:^(NSData *data,
                                                              NSURLResponse *response,
                                                              NSError *error) {
            if (error) {
                [subscriber sendError:error];
                return;
            }
            
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                              options:0
                                                                error:&jsonError];
            if (jsonError) {
                [subscriber sendError:jsonError];
                return;
            }
            
            [subscriber sendNext:json];
            [subscriber sendCompleted];
        }];
        
        [task resume];
        
        return [RACDisposable disposableWithBlock:^{
            [task cancel];
        }];
    }];
}

@end

// 使用示例
[[NetworkService fetchUserWithID:@"123"]
    subscribeNext:^(NSDictionary *response) {
        NSLog(@"用户数据：%@", response);
    } error:^(NSError *error) {
        NSLog(@"错误：%@", error);
    }];
```

### 3. KVO替代
```objectivec
// 使用RAC替代KVO
[RACObserve(self.user, name) subscribeNext:^(NSString *newName) {
    NSLog(@"用户名变更为：%@", newName);
}];

// 值变换
[[RACObserve(self.user, age)
    map:^id(NSNumber *age) {
        return @([age integerValue] >= 18);
    }]
    subscribeNext:^(NSNumber *isAdult) {
        self.adultContentEnabled = [isAdult boolValue];
    }];
```

## 高级特性

### 1. 信号操作
```objectivec
// 信号过滤
[[self.searchField.rac_textSignal
    filter:^BOOL(NSString *text) {
        return text.length > 2;
    }]
    subscribeNext:^(NSString *searchText) {
        [self performSearch:searchText];
    }];

// 信号防抖
[[self.searchField.rac_textSignal
    throttle:0.3]
    subscribeNext:^(NSString *searchText) {
        [self performSearch:searchText];
    }];
```

### 2. 多信号组合
```objectivec
// 组合多个信号
[[RACSignal
    combineLatest:@[self.usernameSignal,
                    self.passwordSignal,
                    self.emailSignal]
    reduce:^(NSString *username,
             NSString *password,
             NSString *email) {
        return @(username.length > 0 &&
                 password.length > 0 &&
                 [email containsString:@"@"]);
    }]
    subscribeNext:^(NSNumber *isValid) {
        self.submitButton.enabled = [isValid boolValue];
    }];
```

## 最佳实践

### 1. MVVM模式
```objectivec
// ViewModel
@interface LoginViewModel : NSObject
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) RACCommand *loginCommand;
@end

@implementation LoginViewModel

- (instancetype)init {
    if (self = [super init]) {
        _loginCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
            return [self loginSignal];
        }];
    }
    return self;
}

- (RACSignal *)loginSignal {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        // 登录逻辑
        return nil;
    }];
}

@end
```

### 2. 内存管理
```objectivec
// 使用weak-strong dance避免循环引用
@weakify(self);
[RACObserve(self.user, name) subscribeNext:^(NSString *name) {
    @strongify(self);
    self.nameLabel.text = name;
}];
```

## 注意事项

1. **内存管理**
   - 注意循环引用
   - 正确使用weak-strong dance

2. **错误处理**
   - 合理处理错误信号
   - 提供错误恢复机制

3. **性能考虑**
   - 避免过度使用信号
   - 注意信号的清理和取消

## 总结

ReactiveCocoa为Objective-C项目提供了强大的响应式编程能力，特别适合处理复杂的异步操作和UI交互。通过合理使用RAC的各种特性，我们可以编写出更加简洁、可维护的代码。在实际开发中，需要注意内存管理和性能优化，同时也要考虑与现有代码的兼容性。