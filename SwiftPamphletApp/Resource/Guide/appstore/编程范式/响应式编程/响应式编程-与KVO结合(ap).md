# 响应式编程与KVO结合

## 简介

KVO (Key-Value Observing) 是 Cocoa 的一个核心特性，结合响应式编程可以更优雅地处理属性变化的观察和响应。

## 基础用法

### 1. 传统KVO
```swift
// 传统KVO实现
class TraditionalObject: NSObject {
    @objc dynamic var value: Int = 0
}

class Observer: NSObject {
    var object: TraditionalObject
    
    init(object: TraditionalObject) {
        self.object = object
        super.init()
        object.addObserver(self,
                          forKeyPath: #keyPath(TraditionalObject.value),
                          options: [.new],
                          context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(TraditionalObject.value) {
            print("值变化为：\(change?[.newKey] ?? 0)")
        }
    }
    
    deinit {
        object.removeObserver(self, forKeyPath: #keyPath(TraditionalObject.value))
    }
}
```

### 2. Combine + KVO
```swift
// 使用Combine观察属性变化
class ModernObject: NSObject {
    @objc dynamic var value: Int = 0
}

class ModernObserver {
    var object: ModernObject
    var cancellables = Set<AnyCancellable>()
    
    init(object: ModernObject) {
        self.object = object
        
        object.publisher(for: \.value)
            .sink { newValue in
                print("值变化为：\(newValue)")
            }
            .store(in: &cancellables)
    }
}
```

## 高级应用

### 1. 多属性观察
```swift
// 观察多个属性的变化
class UserProfile: NSObject {
    @objc dynamic var name: String = ""
    @objc dynamic var age: Int = 0
    @objc dynamic var email: String = ""
}

class ProfileObserver {
    var profile: UserProfile
    var cancellables = Set<AnyCancellable>()
    
    init(profile: UserProfile) {
        self.profile = profile
        
        // 组合多个属性的观察
        Publishers.CombineLatest3(
            profile.publisher(for: \.name),
            profile.publisher(for: \.age),
            profile.publisher(for: \.email)
        )
        .sink { name, age, email in
            print("用户信息更新：\(name), \(age), \(email)")
        }
        .store(in: &cancellables)
    }
}
```

### 2. 值转换和过滤
```swift
// 对观察的值进行处理
class TemperatureSensor: NSObject {
    @objc dynamic var celsius: Double = 0
}

class TemperatureMonitor {
    var sensor: TemperatureSensor
    var cancellables = Set<AnyCancellable>()
    
    init(sensor: TemperatureSensor) {
        self.sensor = sensor
        
        sensor.publisher(for: \.celsius)
            .map { celsius -> String in
                let fahrenheit = celsius * 9/5 + 32
                return String(format: "%.1f°C (%.1f°F)", celsius, fahrenheit)
            }
            .filter { _ in
                // 只在主线程处理UI更新
                Thread.isMainThread
            }
            .sink { formattedTemp in
                print("当前温度：\(formattedTemp)")
            }
            .store(in: &cancellables)
    }
}
```

### 3. SwiftUI集成
```swift
// 在SwiftUI中使用KVO
class WeatherStation: NSObject, ObservableObject {
    @objc dynamic var temperature: Double = 0
    @objc dynamic var humidity: Double = 0
    
    override init() {
        super.init()
        // 定期更新数据
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.temperature = Double.random(in: 20...30)
            self?.humidity = Double.random(in: 40...60)
        }
    }
}

struct WeatherView: View {
    @StateObject private var station = WeatherStation()
    @State private var temperatureHistory: [Double] = []
    
    var body: some View {
        VStack {
            Text("温度: \(station.temperature, specifier: "%.1f")°C")
            Text("湿度: \(station.humidity, specifier: "%.1f")%")
        }
        .onAppear {
            // 使用KVO观察温度变化
            station.publisher(for: \.temperature)
                .sink { newTemp in
                    temperatureHistory.append(newTemp)
                    if temperatureHistory.count > 10 {
                        temperatureHistory.removeFirst()
                    }
                }
                .store(in: &station.objectWillChange.cancellables)
        }
    }
}
```

## 实践技巧

### 1. 错误处理
```swift
// 处理KVO观察中的错误
class NetworkMonitor: NSObject {
    @objc dynamic var status: String = "unknown"
    
    func checkConnection() throws {
        // 模拟网络检查
        let isConnected = Bool.random()
        if isConnected {
            status = "connected"
        } else {
            throw NSError(domain: "NetworkError", code: -1)
        }
    }
}

class ConnectionObserver {
    var monitor: NetworkMonitor
    var cancellables = Set<AnyCancellable>()
    
    init(monitor: NetworkMonitor) {
        self.monitor = monitor
        
        monitor.publisher(for: \.status)
            .tryMap { status -> String in
                guard status == "connected" else {
                    throw NSError(domain: "StatusError", code: -1)
                }
                return status
            }
            .catch { error -> Just<String> in
                print("错误：\(error)")
                return Just("disconnected")
            }
            .sink { status in
                print("网络状态：\(status)")
            }
            .store(in: &cancellables)
    }
}
```

### 2. 性能优化
```swift
// 优化KVO观察的性能
class OptimizedObject: NSObject {
    @objc dynamic var frequentValue: Int = 0
    private var updateTimer: Timer?
    
    override init() {
        super.init()
        // 使用节流控制更新频率
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.frequentValue = Int.random(in: 0...100)
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

class OptimizedObserver {
    var object: OptimizedObject
    var cancellables = Set<AnyCancellable>()
    
    init(object: OptimizedObject) {
        self.object = object
        
        object.publisher(for: \.frequentValue)
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .sink { value in
                print("节流后的值：\(value)")
            }
            .store(in: &cancellables)
    }
}
```

## 注意事项

1. **内存管理**
   - 正确处理观察者的生命周期
   - 避免循环引用

2. **线程安全**
   - 注意在正确的线程上处理UI更新
   - 使用适当的调度器

3. **性能考虑**
   - 合理使用节流和防抖
   - 避免过度观察

## 总结

将KVO与响应式编程结合使用，可以大大简化属性观察的实现，使代码更加简洁和易于维护。通过Combine框架，我们可以优雅地处理属性变化，并结合其他响应式特性实现更复杂的数据流处理。在实际开发中，需要注意内存管理和性能优化，确保应用程序的稳定性和响应性。