import SwiftStore
import SwiftUI

// Define the state
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

// Define the reducer
private func todoReducer(state: TodoState, action: TodoState.Action) -> TodoState {
  var newState = state

  switch action {
  case .add(let text):
    newState.todos.append(TodoState.Todo(text: text))
  case .toggle(let id):
    if let index = newState.todos.firstIndex(where: { $0.id == id }) {
      newState.todos[index].isCompleted.toggle()
    }
  case .delete(let id):
    newState.todos.removeAll(where: { $0.id == id })
  }

  return newState
}

// Example logging middleware
func makeLoggingMiddleware() -> Middleware<TodoState> {
  return { getState, disptach, next, action in
    print("⚡️ Before action: \(action)")
    print("📝 Current state: \(getState())")

    await next(action)

    print("✅ After action: \(action)")
    print("📝 New state: \(getState())")
  }
}

public struct ContentView: View {
  @Store(
    initialState: TodoState(),
    reducer: todoReducer,
    middleware: [makeLoggingMiddleware()]
  ) private var store

  @State private var newTodoText = ""

  public var body: some View {
    NavigationView {
      VStack {
        // Add todo input
        HStack {
          TextField("New todo", text: $newTodoText)
            .textFieldStyle(RoundedBorderTextFieldStyle())

          Button(action: {
            guard !newTodoText.isEmpty else { return }
            store.dispatch(.add(newTodoText))
            newTodoText = ""
          }) {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.blue)
          }
        }
        .padding()

        // Todo list
        List {
          ForEach(store.state.todos) { todo in
            HStack {
              Button(action: {
                store.dispatch(.toggle(todo.id))
              }) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                  .foregroundColor(todo.isCompleted ? .green : .gray)
              }

              Text(todo.text)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .gray : .primary)

              Spacer()

              Button(action: {
                store.dispatch(.delete(todo.id))
              }) {
                Image(systemName: "trash")
                  .foregroundColor(.red)
              }
            }
          }
        }
      }
      .navigationTitle("Todo List")
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
