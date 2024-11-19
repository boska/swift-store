import XCTest

@testable import SwiftStore

final class TodoStoreTests: XCTestCase {
  struct TodoState: StateType {
    var todos: [Todo] = []
    var isLoading: Bool = false
    var error: String? = nil

    struct Todo: Equatable, Identifiable {
      let id: UUID
      var text: String
      var isCompleted: Bool
    }

    enum Action {
      case addTodo(String)
      case removeTodo(UUID)
      case toggleTodo(UUID)
      case editTodo(UUID, String)
      case setLoading(Bool)
      case setError(String?)
    }
  }

  func testTodoMiddleware() async {
    var capturedActions: [TodoState.Action] = []

    let loggingMiddleware: Middleware<TodoState> = { getState, dispatch, next, action in
      capturedActions.append(action)

      if case .setError = action {
        await next(action)
        return
      }

      let currentState = getState()
      if currentState.isLoading {
        await dispatch(.setError("Cannot perform action while loading"))
        return
      }

      await next(action)
    }

    let store = CoreStore(
      initialState: TodoState(),
      reducer: todoReducer,
      middleware: [loggingMiddleware]
    )

    await store.dispatch(.setLoading(true))
    await store.dispatch(.addTodo("Test"))

    XCTAssertEqual(capturedActions.count, 3)
    XCTAssertTrue(store.state.todos.isEmpty)
    XCTAssertNotNil(store.state.error)
  }

  private func todoReducer(state: TodoState, action: TodoState.Action) -> TodoState {
    var newState = state

    switch action {
    case .addTodo(let text):
      let todo = TodoState.Todo(id: UUID(), text: text, isCompleted: false)
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
}
