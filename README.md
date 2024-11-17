# Swift Store

A lightweight, type-safe state management library for Swift. Loose ties to SwiftUI, inspired by Redux and The Elm Architecture.

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-blue.svg)](https://developer.apple.com/xcode/swiftui)
[![License](https://img.shields.io/badge/license-MIT-black.svg)](https://github.com/yourusername/ArchSwift/blob/main/LICENSE)

## Features
- 🎯 **100% tested**: 100% of the code is tested with XCTest.
- 📦 **Lightweight**: No additional dependencies, just Swift
- 📦 **Opt-in SwiftUI wrapper**: `ObservableStore` to easily integrate with SwiftUI
- 🎯 **Type-safe**: Fully type-safe state management with Swift's type system
- 🔄 **Predictable**: One-way data flow with immutable state updates
- 🧩 **Composable**: Easy to compose and reuse reducers and middleware
- ⚡️ **Swift Concurrency**: Built with async/await for better performance
- 🎨 **SwiftUI Integration**: Seamless integration with SwiftUI
- 🧪 **Testable**: Designed for easy testing and debugging

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ArchSwift", from: "1.0.0")
]
```

## Basic Usage

### Define Your State

Your state should conform to `StateType` protocol and include its associated actions:

```swift
struct AppState: StateType {
    var counter: Int = 0
    
    enum Action {
        case increment
        case decrement
    }
}
```

### Create Store

Initialize your store with initial state and a reducer:

```swift
let store = CoreStore(
    initialState: AppState(),
    reducer: { state, action in
        var newState = state
        switch action {
        case .increment:
            newState.counter += 1
        case .decrement:
            newState.counter -= 1
        }
        return newState
    }
)
```

### Use in SwiftUI

Integrate with SwiftUI using `ObservableStore`:

```swift
struct ContentView: View {
    @StateObject private var store = ObservableStore(
        store: CoreStore(
            initialState: AppState(),
            reducer: { state, action in
                var newState = state
                switch action {
                case .increment:
                    newState.counter += 1
                case .decrement:
                    newState.counter -= 1
                }
                return newState
            }
        )
    )
    
    var body: some View {
        VStack {
            Text("Count: \(store.state.counter)")
            
            Button("Increment") {
                store.dispatch(.increment)
            }
            
            Button("Decrement") {
                store.dispatch(.decrement)
            }
        }
    }
}
```

## Advanced Usage

### Middleware

Middleware allows you to intercept actions for logging, side effects, or transformations:

```swift
// Logging middleware
let loggingMiddleware: (AppState, AppState.Action) async -> AppState.Action? = { state, action in
    print("Action: \(action)")
    print("State: \(state)")
    return action
}

// Analytics middleware
let analyticsMiddleware: (AppState, AppState.Action) async -> AppState.Action? = { _, action in
    await Analytics.track(action)
    return action
}

// Store with middleware
let store = CoreStore(
    initialState: AppState(),
    reducer: appReducer,
    middleware: [
        loggingMiddleware,
        analyticsMiddleware
    ]
)
```

### Complex State Example

Here's a more complex example with a todo list:

```swift
struct TodoState: StateType {
    struct Todo: Equatable, Identifiable {
        let id: UUID
        var text: String
        var isCompleted: Bool
    }
    
    var todos: [Todo] = []
    var isLoading: Bool = false
    
    enum Action {
        case addTodo(String)
        case toggleTodo(UUID)
        case removeTodo(UUID)
        case setLoading(Bool)
    }
}

let todoStore = CoreStore(
    initialState: TodoState(),
    reducer: { state, action in
        var newState = state
        switch action {
        case .addTodo(let text):
            let todo = TodoState.Todo(id: UUID(), text: text, isCompleted: false)
            newState.todos.append(todo)
        case .toggleTodo(let id):
            if let index = newState.todos.firstIndex(where: { $0.id == id }) {
                newState.todos[index].isCompleted.toggle()
            }
        case .removeTodo(let id):
            newState.todos.removeAll { $0.id == id }
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        }
        return newState
    }
)
```

## Testing

ArchSwift is designed for testability. Here's how to test your store:

```swift
final class StoreTests: XCTestCase {
    func testCounter() async {
        // Given
        let store = CoreStore(
            initialState: AppState(),
            reducer: { state, action in
                var newState = state
                switch action {
                case .increment:
                    newState.counter += 1
                case .decrement:
                    newState.counter -= 1
                }
                return newState
            }
        )
        
        // When
        await store.dispatch(.increment)
        
        // Then
        XCTAssertEqual(store.state.counter, 1)
        
        // When
        await store.dispatch(.decrement)
        
        // Then
        XCTAssertEqual(store.state.counter, 0)
    }
}
```

## Best Practices

1. Keep your state immutable
2. Make state updates predictable
3. Use middleware for side effects
4. Keep reducers pure
5. Test your stores thoroughly

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+
- Xcode 13.0+

## License

ArchSwift is available under the MIT license. See the LICENSE file for more info.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.