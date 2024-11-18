# SwiftStore

A lightweight, type-safe state management library for Swift with elegant SwiftUI integration through property wrappers.

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-blue.svg)](https://developer.apple.com/xcode/swiftui)
[![License](https://img.shields.io/badge/license-MIT-black.svg)](https://github.com/yourusername/SwiftStore/blob/main/LICENSE)

## Features
- 🎯 **Property Wrapper Integration**: Clean SwiftUI integration with `@Store`
- 🔄 **Middleware Support**: Composable middleware for side effects and logging
- 📦 **Lightweight**: No external dependencies
- ⚡️ **Swift Concurrency**: Built with async/await
- 🧪 **Testable**: Designed for easy testing
- 🎨 **SwiftUI First**: Seamless SwiftUI integration

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

### Use in SwiftUI

```swift
struct ContentView: View {
    @Store(
        initialState: CounterState(),
        reducer: counterReducer
    ) private var store
    
    var body: some View {
        VStack {
            Text("Count: \(store.state.count)")
            
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

## Middleware

Create and compose middleware for logging, analytics, or other side effects:

```swift
// Logging Middleware
func makeLoggingMiddleware<State: StateType>() -> Middleware<State> {
    return { store, next, action in
        print("⚡️ Before action: \(action)")
        print("📝 Current state: \(store.state)")
        
        await next(action)
        
        print("✅ After action: \(action)")
        print("📝 New state: \(store.state)")
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

// Use middleware in your view
struct ContentView: View {
    @Store(
        initialState: CounterState(),
        reducer: counterReducer,
        middleware: [
            makeLoggingMiddleware(),
            makeAnalyticsMiddleware()
        ]
    ) private var store
    
    var body: some View {
        // ... view implementation ...
    }
}
```

## Complex Example: Todo List

```swift
struct TodoState: StateType {
    struct Todo: Identifiable, Equatable {
        let id: UUID = UUID()
        var text: String
        var isCompleted: Bool = false
    }
    
    var todos: [Todo] = []
    
    enum Action {
        case add(String)
        case toggle(UUID)
        case delete(UUID)
    }
}

struct TodoListView: View {
    @Store(
        initialState: TodoState(),
        reducer: todoReducer,
        middleware: [makeLoggingMiddleware()]
    ) private var store
    @State private var newTodoText = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(store.state.todos) { todo in
                    HStack {
                        Text(todo.text)
                        Spacer()
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                        }
                    }
                    .onTapGesture {
                        store.dispatch(.toggle(todo.id))
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first,
                       let id = store.state.todos[safe: index]?.id {
                        store.dispatch(.delete(id))
                    }
                }
            }
            
            HStack {
                TextField("New Todo", text: $newTodoText)
                Button("Add") {
                    store.dispatch(.add(newTodoText))
                    newTodoText = ""
                }
            }
            .padding()
        }
    }
}
```

## Testing

Testing is straightforward with the store:

```swift
final class TodoStoreTests: XCTestCase {
    func testAddTodo() async {
        // Given
        @Store(
            initialState: TodoState(),
            reducer: todoReducer
        ) var store
        
        // When
        await store.dispatch(.add("Test Todo"))
        
        // Then
        XCTAssertEqual(store.state.todos.count, 1)
        XCTAssertEqual(store.state.todos.first?.text, "Test Todo")
    }
    
    func testToggleTodo() async {
        // Given
        @Store(
            initialState: TodoState(todos: [
                .init(text: "Test Todo")
            ]),
            reducer: todoReducer
        ) var store
        
        // When
        await store.dispatch(.toggle(store.state.todos[0].id))
        
        // Then
        XCTAssertTrue(store.state.todos[0].isCompleted)
    }
}
```

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftStore", from: "1.0.0")
]
```

## License

SwiftStore is available under the MIT license. See the LICENSE file for more info.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.