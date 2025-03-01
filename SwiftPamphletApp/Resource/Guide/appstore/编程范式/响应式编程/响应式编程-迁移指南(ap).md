# 响应式框架迁移指南：从RxSwift/ReactiveSwift到Combine

## 简介

随着Apple推出Combine框架，越来越多的iOS开发者开始考虑将现有的RxSwift或ReactiveSwift项目迁移到Combine。本指南将帮助你平稳地完成这个转换过程。

## 核心概念对比

### 1. 基础类型对应关系

```swift
// RxSwift -> Combine
Observable<T> -> Publisher<T, Error>
Subject -> Subject
Driver -> @Published property

// ReactiveSwift -> Combine
Signal<T, E> -> Publisher<T, E>
SignalProducer -> Publisher
Property -> @Published property
```

### 2. 操作符映射

```swift
// RxSwift -> Combine
map -> map
flatMap -> flatMap
filter -> filter
combineLatest -> combineLatest
merge -> merge
concat -> append

// ReactiveSwift -> Combine
map -> map
flatMap -> flatMap
filter -> filter
combineLatest -> combineLatest
concat -> append
```

## 常见模式转换

### 1. 网络请求

#### 基本请求

```swift
// RxSwift
class NetworkService {
    let disposeBag = DisposeBag()
    
    func fetchData<T: Decodable>(request: URLRequest) -> Observable<T> {
        return URLSession.rx.data(request: request)
            .map { try JSONDecoder().decode(T.self, from: $0) }
            .observe(on: MainScheduler.instance)
    }
}

// 使用示例
networkService.fetchData(request: request)
    .subscribe(onNext: { (response: Response) in
        // 处理响应
    }, onError: { error in
        // 处理错误
    })
    .disposed(by: disposeBag)

// ReactiveSwift
class NetworkService {
    func fetchData<T: Decodable>(request: URLRequest) -> SignalProducer<T, Error> {
        return URLSession.shared.reactive.data(with: request)
            .map { try JSONDecoder().decode(T.self, from: $0.0) }
            .observe(on: UIScheduler())
    }
}

// 使用示例
networkService.fetchData(request: request)
    .startWithResult { result in
        switch result {
        case .success(let response):
            // 处理响应
        case .failure(let error):
            // 处理错误
        }
    }

// Combine
class NetworkService {
    var cancellables = Set<AnyCancellable>()
    
    func fetchData<T: Decodable>(request: URLRequest) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// 使用示例
networkService.fetchData(request: request)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                // 处理错误
            }
        },
        receiveValue: { (response: Response) in
            // 处理响应
        }
    )
    .store(in: &cancellables)
```

#### 错误重试处理

```swift
// RxSwift
class NetworkService {
    func fetchWithRetry<T: Decodable>(request: URLRequest) -> Observable<T> {
        return URLSession.rx.data(request: request)
            .retry(3)
            .map { try JSONDecoder().decode(T.self, from: $0) }
            .catch { error -> Observable<T> in
                if let fallbackData = self.getFallbackData() {
                    return .just(fallbackData)
                }
                return .error(error)
            }
    }
}

// ReactiveSwift
class NetworkService {
    func fetchWithRetry<T: Decodable>(request: URLRequest) -> SignalProducer<T, Error> {
        return URLSession.shared.reactive.data(with: request)
            .retry(upTo: 3)
            .map { try JSONDecoder().decode(T.self, from: $0.0) }
            .flatMapError { error -> SignalProducer<T, Error> in
                if let fallbackData = self.getFallbackData() {
                    return SignalProducer(value: fallbackData)
                }
                return SignalProducer(error: error)
            }
    }
}

// Combine
class NetworkService {
    func fetchWithRetry<T: Decodable>(request: URLRequest) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .retry(3)
            .map { $0.data }
            .decode(type: T.self, decoder: JSONDecoder())
            .catch { error -> AnyPublisher<T, Error> in
                if let fallbackData = self.getFallbackData() {
                    return Just(fallbackData)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

#### 请求链式组合

```swift
// RxSwift
class UserService {
    func fetchUserProfile(userId: String) -> Observable<UserProfile> {
        return fetchUser(userId: userId)
            .flatMap { user -> Observable<(User, UserDetail)> in
                return self.fetchUserDetail(userId: user.id)
                    .map { detail in (user, detail) }
            }
            .flatMap { user, detail -> Observable<UserProfile> in
                return self.fetchUserPreferences(userId: user.id)
                    .map { preferences in
                        UserProfile(user: user,
                                  detail: detail,
                                  preferences: preferences)
                    }
            }
    }
}

// ReactiveSwift
class UserService {
    func fetchUserProfile(userId: String) -> SignalProducer<UserProfile, Error> {
        return fetchUser(userId: userId)
            .flatMap(.latest) { user -> SignalProducer<(User, UserDetail), Error> in
                return self.fetchUserDetail(userId: user.id)
                    .map { detail in (user, detail) }
            }
            .flatMap(.latest) { user, detail -> SignalProducer<UserProfile, Error> in
                return self.fetchUserPreferences(userId: user.id)
                    .map { preferences in
                        UserProfile(user: user,
                                  detail: detail,
                                  preferences: preferences)
                    }
            }
    }
}

// Combine
class UserService {
    func fetchUserProfile(userId: String) -> AnyPublisher<UserProfile, Error> {
        return fetchUser(userId: userId)
            .flatMap { user -> AnyPublisher<(User, UserDetail), Error> in
                return self.fetchUserDetail(userId: user.id)
                    .map { detail in (user, detail) }
                    .eraseToAnyPublisher()
            }
            .flatMap { user, detail -> AnyPublisher<UserProfile, Error> in
                return self.fetchUserPreferences(userId: user.id)
                    .map { preferences in
                        UserProfile(user: user,
                                  detail: detail,
                                  preferences: preferences)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

### 2. UI绑定

#### 基本UI绑定

```swift
// RxSwift
class SearchViewController: UIViewController {
    let searchBar = UISearchBar()
    let tableView = UITableView()
    let disposeBag = DisposeBag()
    let viewModel = SearchViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 搜索框绑定
        searchBar.rx.text.orEmpty
            .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: viewModel.searchText)
            .disposed(by: disposeBag)
        
        // 结果绑定
        viewModel.searchResults
            .bind(to: tableView.rx.items(cellIdentifier: "Cell")) { _, item, cell in
                cell.textLabel?.text = item.title
            }
            .disposed(by: disposeBag)
        
        // 加载状态绑定
        viewModel.isLoading
            .bind(to: activityIndicator.rx.isAnimating)
            .disposed(by: disposeBag)
    }
}

// ReactiveSwift
class SearchViewController: UIViewController {
    let searchBar = UISearchBar()
    let tableView = UITableView()
    let viewModel = SearchViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 搜索框绑定
        searchBar.reactive.continuousTextValues
            .debounce(0.3, on: QueueScheduler.main)
            .skipRepeats()
            .observeValues { [weak self] text in
                self?.viewModel.searchText.value = text
            }
        
        // 结果绑定
        viewModel.searchResults.producer
            .startWithValues { [weak self] results in
                self?.tableView.reloadData()
            }
        
        // 加载状态绑定
        viewModel.isLoading.producer
            .startWithValues { [weak self] isLoading in
                self?.activityIndicator.isAnimating = isLoading
            }
    }
}

// Combine
class SearchViewController: UIViewController {
    let searchBar = UISearchBar()
    let tableView = UITableView()
    private var cancellables = Set<AnyCancellable>()
    let viewModel = SearchViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 搜索框绑定
        NotificationCenter.default.publisher(for: UISearchBar.textDidChangeNotification, object: searchBar)
            .compactMap { ($0.object as? UISearchBar)?.text }
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: \SearchViewModel.searchText, on: viewModel)
            .store(in: &cancellables)
        
        // 结果绑定
        viewModel.$searchResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // 加载状态绑定
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAnimating, on: activityIndicator)
            .store(in: &cancellables)
    }
}
```

### 3. 状态管理

```swift
// RxSwift
class StateManager {
    private let stateSubject = BehaviorSubject<AppState>(value: .initial)
    
    var state: Observable<AppState> {
        return stateSubject.asObservable()
    }
    
    func updateState(_ action: Action) {
        let currentState = try? stateSubject.value()
        let newState = reducer.reduce(currentState, action)
        stateSubject.onNext(newState)
    }
}

// ReactiveSwift
class StateManager {
    private let stateProperty = MutableProperty<AppState>(.initial)
    
    var state: Property<AppState> {
        return Property(stateProperty)
    }
    
    func updateState(_ action: Action) {
        let newState = reducer.reduce(stateProperty.value, action)
        stateProperty.value = newState
    }
}

// Combine
class StateManager {
    @Published private(set) var state: AppState = .initial
    
    func updateState(_ action: Action) {
        state = reducer.reduce(state, action)
    }
}

// 使用示例
class ViewController: UIViewController {
    let stateManager = StateManager()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stateManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(with: state)
            }
            .store(in: &cancellables)
    }
}
```

## 迁移策略

### 1. 渐进式迁移

- 按模块逐步迁移
- 使用适配器模式过渡
- 保持代码可测试性

### 2. 迁移注意事项

1. **错误类型处理**
   - RxSwift/ReactiveSwift 可以自定义错误类型
   - Combine 的 Publisher 需要明确指定错误类型
   - 使用 `setFailureType` 和 `mapError` 进行错误类型转换

2. **取消操作差异**
   - RxSwift 使用 DisposeBag
   - ReactiveSwift 使用 Disposable
   - Combine 使用 AnyCancellable 和 Set<AnyCancellable>

3. **线程调度**
   - RxSwift: `observeOn`, `subscribeOn`
   - ReactiveSwift: `observe(on:)`, `start(on:)`