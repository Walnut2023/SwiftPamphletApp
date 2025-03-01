# RxSwift框架

## 简介

RxSwift是ReactiveX的Swift版本实现，提供了强大的响应式编程功能。它是一个跨平台的响应式编程库，在iOS社区有广泛的应用。

## 核心概念

### 1. Observable（可观察序列）
```swift
// 创建Observable
let observable = Observable.just(1)
let arrayObservable = Observable.from([1, 2, 3])

// 自定义Observable
let customObservable = Observable<String>.create { observer in
    observer.onNext("Hello")
    observer.onCompleted()
    return Disposables.create()
}
```

### 2. Observer（观察者）
```swift
// 基本订阅
observable.subscribe(onNext: { value in
    print("收到值：\(value)")
}, onError: { error in
    print("发生错误：\(error)")
}, onCompleted: {
    print("完成")
})

// 使用subscribe简写
observable.subscribe { event in
    switch event {
    case .next(let value):
        print(value)
    case .error(let error):
        print(error)
    case .completed:
        print("完成")
    }
}
```

## 常用操作符

### 1. 转换操作符
```swift
// map操作符
observable
    .map { $0 * 2 }
    .subscribe(onNext: { value in
        print("转换后的值：\(value)")
    })

// flatMap操作符
struct User {
    let name: String
    let friends: Observable<[String]>
}

let user = User(name: "张三", friends: Observable.just(["李四", "王五"]))
Observable.just(user)
    .flatMap { $0.friends }
    .subscribe(onNext: { friends in
        print("好友列表：\(friends)")
    })
```

### 2. 过滤操作符
```swift
// filter操作符
observable
    .filter { $0 > 5 }
    .subscribe(onNext: { value in
        print("大于5的值：\(value)")
    })

// distinctUntilChanged操作符
Observable.from([1, 1, 2, 2, 3])
    .distinctUntilChanged()
    .subscribe(onNext: { value in
        print(value) // 输出：1, 2, 3
    })
```

### 3. 组合操作符
```swift
// merge操作符
let subject1 = PublishSubject<Int>()
let subject2 = PublishSubject<Int>()

Observable.merge([subject1, subject2])
    .subscribe(onNext: { value in
        print(value)
    })

// combineLatest操作符
Observable.combineLatest(subject1, subject2) { a, b in
    return "\(a) + \(b) = \(a + b)"
}
.subscribe(onNext: { result in
    print(result)
})
```

## 实际应用

### 1. 网络请求
```swift
// 封装网络请求
class NetworkService {
    static func request<T: Decodable>(_ url: URL) -> Observable<T> {
        return Observable.create { observer in
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    observer.onError(error)
                    return
                }
                
                guard let data = data else {
                    observer.onError(NSError(domain: "", code: -1))
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    observer.onNext(decoded)
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
            }
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
}

// 使用示例
NetworkService.request<User>(userURL)
    .observe(on: MainScheduler.instance)
    .subscribe(onNext: { user in
        print("获取到用户：\(user)")
    })
    .disposed(by: disposeBag)
```

### 2. UI绑定
```swift
// 使用RxCocoa进行UI绑定
class LoginViewModel {
    let username = BehaviorRelay<String>(value: "")
    let password = BehaviorRelay<String>(value: "")
    
    var isValid: Observable<Bool> {
        return Observable.combineLatest(username, password) { username, password in
            return username.count >= 4 && password.count >= 6
        }
    }
}

class LoginViewController: UIViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    let viewModel = LoginViewModel()
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 双向绑定
        usernameTextField.rx.text.orEmpty
            .bind(to: viewModel.username)
            .disposed(by: disposeBag)
        
        passwordTextField.rx.text.orEmpty
            .bind(to: viewModel.password)
            .disposed(by: disposeBag)
        
        // 启用状态绑定
        viewModel.isValid
            .bind(to: loginButton.rx.isEnabled)
            .disposed(by: disposeBag)
    }
}
```

### 3. 手势处理
```swift
// 处理手势事件
view.rx.tapGesture()
    .when(.recognized)
    .subscribe(onNext: { _ in
        print("视图被点击")
    })
    .disposed(by: disposeBag)

// 组合手势
Observable.merge(
    view1.rx.tapGesture().when(.recognized).map { _ in "view1" },
    view2.rx.tapGesture().when(.recognized).map { _ in "view2" }
)
.subscribe(onNext: { viewName in
    print("\(viewName) 被点击")
})
.disposed(by: disposeBag)
```

## 内存管理

### 1. DisposeBag
```swift
// 使用DisposeBag管理订阅
class ViewModel {
    let disposeBag = DisposeBag()
    
    init() {
        Observable.interval(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { value in
                print(value)
            })
            .disposed(by: disposeBag)
    }
}
```

### 2. 避免内存泄漏
```swift
// 使用weak self
observable
    .subscribe(onNext: { [weak self] value in
        self?.process(value)
    })
    .disposed(by: disposeBag)
```

## 调试技巧

### 1. 调试操作符
```swift
// 使用debug操作符
observable
    .debug("调试标识", trimOutput: false)
    .subscribe()
    .disposed(by: disposeBag)

// 使用do操作符
observable
    .do(onNext: { value in
        print("即将发送：\(value)")
    }, onError: { error in
        print("发生错误：\(error)")
    })
    .subscribe()
    .disposed(by: disposeBag)
```

## 注意事项

1. **线程调度**
   - 使用合适的Scheduler
   - 注意避免线程死锁

2. **错误处理**
   - 合理使用catch操作符
   - 提供错误恢复机制

3. **性能优化**
   - 避免过度使用操作符
   - 及时释放不需要的订阅

## 总结

RxSwift提供了强大而灵活的响应式编程能力，特别适合处理异步操作、UI事件和数据流。通过合理使用操作符和正确的内存管理，我们可以构建出高效、可维护的响应式应用程序。在实际开发中，需要注意选择合适的操作符，并时刻关注内存管理和性能优化。