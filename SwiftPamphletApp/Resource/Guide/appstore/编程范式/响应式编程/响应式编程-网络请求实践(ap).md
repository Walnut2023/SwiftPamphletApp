# 响应式编程网络请求实践

## 简介

响应式编程在处理网络请求时具有独特优势，可以优雅地处理异步操作、错误处理和数据转换。本文将介绍如何使用 Combine 响应式框架处理网络请求。

## Combine 实现

### 1. 基本网络请求
```swift
// 基本的网络请求封装
class NetworkService {
    static func fetch<T: Decodable>(_ url: URL) -> AnyPublisher<T, Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// 使用示例
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

var cancellables = Set<AnyCancellable>()

NetworkService.fetch<User>(userURL)
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("请求完成")
            case .failure(let error):
                print("请求失败: \(error)")
            }
        },
        receiveValue: { user in
            print("获取到用户: \(user)")
        }
    )
    .store(in: &cancellables)
```

### 2. 请求重试和超时
```swift
// 添加重试和超时机制
extension NetworkService {
    static func fetchWithRetry<T: Decodable>(_ url: URL) -> AnyPublisher<T, Error> {
        fetch(url)
            .retry(3) // 失败时重试3次
            .timeout(.seconds(30), scheduler: DispatchQueue.main) // 30秒超时
            .eraseToAnyPublisher()
    }
}
```

### 3. 请求链式调用
```swift
// 链式网络请求
struct Post: Codable {
    let id: Int
    let userId: Int
    let title: String
}

struct Comment: Codable {
    let postId: Int
    let content: String
}

class PostService {
    static func fetchPostAndComments(postId: Int) -> AnyPublisher<(Post, [Comment]), Error> {
        let postURL = URL(string: "https://api.example.com/posts/\(postId)")!
        let commentsURL = URL(string: "https://api.example.com/posts/\(postId)/comments")!
        
        return Publishers.Zip(
            NetworkService.fetch(postURL),
            NetworkService.fetch(commentsURL)
        )
        .eraseToAnyPublisher()
    }
}
```

## 错误处理

### 1. 自定义错误
```swift
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(Int)
    case noData
}

class NetworkManager {
    static func request<T: Decodable>(_ url: URL) -> AnyPublisher<T, NetworkError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                if httpResponse.statusCode == 404 {
                    throw NetworkError.serverError(404)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> NetworkError in
                switch error {
                case is DecodingError:
                    return .decodingError
                case let networkError as NetworkError:
                    return networkError
                default:
                    return .invalidResponse
                }
            }
            .eraseToAnyPublisher()
    }
}
```

### 2. 错误恢复
```swift
// 错误恢复机制
extension NetworkManager {
    static func requestWithFallback<T: Decodable>(
        _ url: URL,
        fallback: T
    ) -> AnyPublisher<T, Never> {
        request(url)
            .catch { error -> AnyPublisher<T, Never> in
                print("Error occurred: \(error), using fallback value")
                return Just(fallback)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

## 请求优化

### 1. 缓存处理
```swift
class CachedNetworkManager {
    static let cache = NSCache<NSString, AnyObject>()
    
    static func cachedRequest<T: Codable>(
        _ url: URL,
        cacheKey: String
    ) -> AnyPublisher<T, Error> {
        if let cachedData = cache.object(forKey: cacheKey as NSString) as? T {
            return Just(cachedData)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return NetworkService.fetch(url)
            .handleEvents(receiveOutput: { value in
                cache.setObject(value as AnyObject, forKey: cacheKey as NSString)
            })
            .eraseToAnyPublisher()
    }
}
```

### 2. 请求合并
```swift
// 合并多个请求
class BatchRequestManager {
    static func batchFetch<T: Decodable>(
        urls: [URL]
    ) -> AnyPublisher<[T], Error> {
        urls.map { url in
            NetworkService.fetch(url)
        }
        .publisher
        .flatMap { $0 }
        .collect()
        .eraseToAnyPublisher()
    }
}
```

## 实际应用示例

### 1. 刷新列表
```swift
class ListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    func refreshList() {
        isLoading = true
        
        NetworkService.fetch(listURL)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            })
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] items in
                    self?.items = items
                }
            )
            .store(in: &cancellables)
    }
}
```

### 2. 图片加载
```swift
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var cancellables = Set<AnyCancellable>()
    
    func loadImage(from url: URL) {
        URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: &$image)
    }
}
```

## 最佳实践

1. **请求管理**
   - 合理管理取消订阅
   - 使用合适的调度器

2. **错误处理**
   - 提供清晰的错误类型
   - 实现优雅的错误恢复

3. **性能优化**
   - 实现请求缓存
   - 避免重复请求

## 总结

响应式编程为网络请求处理提供了强大而优雅的解决方案。通过合理使用Combine或其他响应式框架，我们可以轻松处理异步操作、错误处理和数据转换等复杂场景。在实际开发中，需要注意请求的性能优化和错误处理，同时保持代码的可维护性。