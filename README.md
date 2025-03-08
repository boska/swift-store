# 

# SwiftStore

A lightweight, type-safe state management library for Swift.

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-black.svg)](https://github.com/yourusername/SwiftStore/blob/main/LICENSE)

## Features
- **Middleware Support**: Composable middleware for side effects and logging
- **Lightweight**: No external dependencies
- **Swift Concurrency**: Built with async/await
- **Testable**: Designed for easy testing

## Basic Usage  

### Define Your State

```swift
struct CounterState: StateType {
    var count: Int = 0
    
    enum Action {
        case increment
        case decrement
    }
}
```

### Create Your Reducer

```swift
func counterReducer(state: CounterState, action: CounterState.Action) -> CounterState {
    var newState = state
    switch action {
    case .increment:
        newState.count += 1
    case .decrement:
        newState.count -= 1
    }
    return newState
}
```

## Middleware

Create and compose middleware for logging, analytics, or other side effects:

```swift
/// Creates a logging middleware that traces the complete action dispatch lifecycle.
/// 
/// The middleware executes in the following sequence:
/// 1. Pre-action: Logs the incoming action and current state
/// 2. Action: Passes the action to the next middleware in chain
/// 3. Post-action: Logs the completed action and resulting state
///
/// Example output:
/// ```
/// ⚡️ Before action: setTheme(dark)
/// Current state: AppSettings(theme: system, ...)
/// After action: setTheme(dark)
/// New state: AppSettings(theme: dark, ...)
/// ```
///
/// - Returns: A middleware function that logs state changes and actions
func makeLoggingMiddleware<State: StateType>() -> Middleware<State> {
    return { store, next, action in
        print("⚡️ Before action: \(action)")
        print("Current state: \(store.state)")
        
        await next(action)
        
        print("After action: \(action)")
        print("New state: \(store.state)")
    }
}

// Analytics Middleware
func makeAnalyticsMiddleware<State: StateType>() -> Middleware<State> {
    return { store, next, action in
        await Analytics.track("action_dispatched", properties: [
            "action": String(describing: action)
        ])
        
        await next(action)
    }
}

## Complex Example: App Settings

```swift
struct AppSettings: StateType {
    enum Theme: String, CaseIterable {
        case system
        case light
        case dark
    }
    
    struct Locale: Equatable {
        var language: String
        var region: String
        
        static let current = Locale(
            language: Bundle.main.preferredLocalizations.first ?? "en",
            region: Locale.current.regionCode ?? "US"
        )
    }
    
    var theme: Theme = .system
    var locale: Locale = .current
    
    enum Action {
        case setTheme(Theme)
        case setLocale(Locale)
        case resetToDefaults
    }
}

private func settingsReducer(state: AppSettings, action: AppSettings.Action) -> AppSettings {
    var newState = state
    
    switch action {
    case .setTheme(let theme):
        newState.theme = theme
    case .setLocale(let locale):
        newState.locale = locale
    case .resetToDefaults:
        newState.theme = .system
        newState.locale = .current
    }
    
    return newState
}

// Persistence Middleware
func makePersistenceMiddleware<State: StateType>() -> Middleware<State> {
    return { store, next, action in
        await next(action)
        
        // Persist state changes to UserDefaults
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(store.state) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }
}

## Testing

Testing is straightforward with the store:

```swift
final class TodoStoreTests: XCTestCase {
    func testAddTodo() async {
        // Given
        let store = CoreStore(
            initialState: TodoState(),
            reducer: todoReducer
        )
        
        // When
        await store.dispatch(.add("Test Todo"))
        
        // Then
        XCTAssertEqual(store.state.todos.count, 1)
        XCTAssertEqual(store.state.todos.first?.text, "Test Todo")
    }
    
    func testToggleTodo() async {
        // Given
        let store = CoreStore(
            initialState: TodoState(todos: [
                .init(text: "Test Todo")
            ]),
            reducer: todoReducer
        )
        
        // When
        await store.dispatch(.toggle(store.state.todos[0].id))
        
        // Then
        XCTAssertTrue(store.state.todos[0].isCompleted)
    }
}

## Requirements

- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/boska/swift-store", from: "0.0.5")
]
```

## License

SwiftStore is available under the MIT license. See the LICENSE file for more info.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.