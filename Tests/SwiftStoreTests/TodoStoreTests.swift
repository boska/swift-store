import XCTest

@testable import SwiftStore

final class TodoStoreTests: XCTestCase {
  struct Todo: Equatable, Identifiable {
    let id: UUID
    var text: String
    var isCompleted: Bool
  }

  struct TodoState: StateType {
    var todos: [Todo] = []
    var isLoading: Bool = false
    var error: String? = nil

    enum Action {
      case addTodo(String)
      case removeTodo(UUID)
      case toggleTodo(UUID)
      case editTodo(UUID, String)
      case setLoading(Bool)
      case setError(String?)
    }
  }

  var store: CoreStore<TodoState>!

  override func setUp() {
    store = CoreStore(
      initialState: TodoState(),
      reducer: { state, action in
        var newState = state

        switch action {
        case .addTodo(let text):
          let todo = Todo(id: UUID(), text: text, isCompleted: false)
          newState.todos.append(todo)

        case .removeTodo(let id):
          newState.todos.removeAll { $0.id == id }

        case .toggleTodo(let id):
          if let index = newState.todos.firstIndex(where: { $0.id == id }) {
            newState.todos[index].isCompleted.toggle()
          }

        case .editTodo(let id, let newText):
          if let index = newState.todos.firstIndex(where: { $0.id == id }) {
            newState.todos[index].text = newText
          }

        case .setLoading(let isLoading):
          newState.isLoading = isLoading

        case .setError(let error):
          newState.error = error
        }

        return newState
      }
    )
  }

  func testAddTodo() async {
    // When
    await store.dispatch(.addTodo("Buy milk"))

    // Then
    XCTAssertEqual(store.state.todos.count, 1)
    XCTAssertEqual(store.state.todos.first?.text, "Buy milk")
    XCTAssertFalse(store.state.todos.first?.isCompleted ?? true)
  }

  func testRemoveTodo() async {
    // Given
    await store.dispatch(.addTodo("Buy milk"))
    let todoId = store.state.todos.first!.id

    // When
    await store.dispatch(.removeTodo(todoId))

    // Then
    XCTAssertTrue(store.state.todos.isEmpty)
  }

  func testToggleTodo() async {
    // Given
    await store.dispatch(.addTodo("Buy milk"))
    let todoId = store.state.todos.first!.id

    // When
    await store.dispatch(.toggleTodo(todoId))

    // Then
    XCTAssertTrue(store.state.todos.first?.isCompleted ?? false)

    // And when toggled again
    await store.dispatch(.toggleTodo(todoId))

    // Then
    XCTAssertFalse(store.state.todos.first?.isCompleted ?? true)
  }

  func testEditTodo() async {
    // Given
    await store.dispatch(.addTodo("Buy milk"))
    let todoId = store.state.todos.first!.id

    // When
    await store.dispatch(.editTodo(todoId, "Buy almond milk"))

    // Then
    XCTAssertEqual(store.state.todos.first?.text, "Buy almond milk")
  }

  func testLoadingState() async {
    // When
    await store.dispatch(.setLoading(true))

    // Then
    XCTAssertTrue(store.state.isLoading)

    // And when
    await store.dispatch(.setLoading(false))

    // Then
    XCTAssertFalse(store.state.isLoading)
  }

  func testErrorHandling() async {
    // When
    await store.dispatch(.setError("Network error"))

    // Then
    XCTAssertEqual(store.state.error, "Network error")

    // And when cleared
    await store.dispatch(.setError(nil))

    // Then
    XCTAssertNil(store.state.error)
  }

  func testMultipleOperations() async {
    // Given
    await store.dispatch(.addTodo("Buy milk"))
    await store.dispatch(.addTodo("Buy eggs"))

    // When
    let milkId = store.state.todos.first!.id
    await store.dispatch(.toggleTodo(milkId))
    await store.dispatch(.editTodo(milkId, "Buy almond milk"))

    // Then
    XCTAssertEqual(store.state.todos.count, 2)
    XCTAssertEqual(store.state.todos.first?.text, "Buy almond milk")
    XCTAssertTrue(store.state.todos.first?.isCompleted ?? false)
    XCTAssertEqual(store.state.todos.last?.text, "Buy eggs")
    XCTAssertFalse(store.state.todos.last?.isCompleted ?? true)
  }
}
