import Foundation
import SwiftStore
import Rainbow

// Terminal control codes
enum TerminalControl {
    static let up = "\u{001B}[A"
    static let down = "\u{001B}[B"
    static let right = "\u{001B}[C"
    static let left = "\u{001B}[D"
    static let clear = "\u{001B}[2J\u{001B}[H"
    static let clearLine = "\u{001B}[2K"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
}

// Menu options
enum MenuOption: String, CaseIterable {
    case addTodo = "Add Todo"
    case completeTodo = "Complete Todo"
    case removeTodo = "Remove Todo"
    case listTodos = "List Todos"
    case exit = "Exit"
}

// Terminal raw mode handling
final class TerminalConfig {
    private var originalTermios: termios
    
    init() {
        originalTermios = termios()
        tcgetattr(STDIN_FILENO, &originalTermios)
    }
    
    func enableRawMode() {
        var raw = originalTermios
        raw.c_lflag &= ~UInt32(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }
    
    func disableRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }
    
    deinit {
        disableRawMode()
    }
}

// Define the state for a simple todo list application
struct TodoState: StateType {
    var todos: [String] = []
    var completedTodos: [String] = []
    
    enum Action {
        case add(String)
        case complete(Int)
        case remove(Int)
        case list
    }
}

// Create the reducer to handle state changes
func todoReducer(state: TodoState, action: TodoState.Action) -> TodoState {
    var newState = state
    
    switch action {
    case .add(let todo):
        newState.todos.append(todo)
        print("✅ Added todo: \(todo)")
        
    case .complete(let index):
        guard index < state.todos.count else {
            print("❌ Invalid index")
            return state
        }
        let todo = state.todos[index]
        newState.completedTodos.append(todo)
        newState.todos.remove(at: index)
        print("🎉 Completed todo: \(todo)")
        
    case .remove(let index):
        guard index < state.todos.count else {
            print("❌ Invalid index")
            return state
        }
        let todo = state.todos[index]
        newState.todos.remove(at: index)
        print("🗑️ Removed todo: \(todo)")
        
    case .list:
        print("\n📝 Current Todos:")
        if state.todos.isEmpty {
            print("   No todos!")
        } else {
            for (index, todo) in state.todos.enumerated() {
                print("   \(index). \(todo)")
            }
        }
        
        print("\n✨ Completed Todos:")
        if state.completedTodos.isEmpty {
            print("   No completed todos!")
        } else {
            for (index, todo) in state.completedTodos.enumerated() {
                print("   \(index). \(todo)")
            }
        }
        print("")
    }
    
    return newState
}

// Create logging middleware
func createLoggingMiddleware<State: StateType>() -> Middleware<State> {
    return { getState, dispatch, next, action in
        print("\n🔄 Action: \(action)")
        await next(action)
        print("📊 New State: \(getState())\n")
    }
}

// Create the store
let store = CoreStore(
    initialState: TodoState(),
    reducer: todoReducer,
    middleware: [createLoggingMiddleware()]
)

// Helper function to read a single character
func readChar() -> UInt8? {
    var input: UInt8 = 0
    let count = read(STDIN_FILENO, &input, 1)
    return count == 1 ? input : nil
}

// Helper function to display menu
func displayMenu(options: [MenuOption], selectedIndex: Int) {
    print(TerminalControl.clear, terminator: "")
    print("🎯 Todo List Manager".blue.bold)
    print("Use arrow keys to navigate and Enter to select\n".green)
    
    for (index, option) in options.enumerated() {
        if index == selectedIndex {
            print(" ▶️  ".green + option.rawValue.white.bold)
        } else {
            print("    " + option.rawValue)
        }
    }
}

// Helper function to handle menu selection
func handleMenuSelection(_ option: MenuOption, store: CoreStore<TodoState>) async {
    switch option {
    case .addTodo:
        print("\nEnter todo: ", terminator: "")
        if let todo = Swift.readLine(), !todo.isEmpty {
            await store.dispatch(.add(todo))
        }
        
    case .completeTodo:
        await store.dispatch(.list)
        print("\nEnter index to complete: ", terminator: "")
        if let input = Swift.readLine(),
           let index = Int(input) {
            await store.dispatch(.complete(index))
        }
        
    case .removeTodo:
        await store.dispatch(.list)
        print("\nEnter index to remove: ", terminator: "")
        if let input = Swift.readLine(),
           let index = Int(input) {
            await store.dispatch(.remove(index))
        }
        
    case .listTodos:
        await store.dispatch(.list)
        print("\nPress Enter to continue...")
        _ = Swift.readLine()
        
    case .exit:
        break
    }
}

// Main program loop
let terminalConfig = TerminalConfig()
terminalConfig.enableRawMode()
print(TerminalControl.hideCursor, terminator: "")

let options = MenuOption.allCases
var selectedIndex = 0
var running = true

mainLoop: while running {
    displayMenu(options: options, selectedIndex: selectedIndex)
    
    guard let char = readChar() else { continue }
    
    switch char {
    case 27:
        // Handle arrow keys (escape sequences)
        _ = readChar() // Skip [
        if let arrow = readChar() {
            switch arrow {
            case 65: // Up arrow
                selectedIndex = (selectedIndex - 1 + options.count) % options.count
            case 66: // Down arrow
                selectedIndex = (selectedIndex + 1) % options.count
            default:
                break
            }
        }
        
    case 13: // Enter key
        let selectedOption = options[selectedIndex]
        if selectedOption == .exit {
            running = false
            break mainLoop
        }
        
        // Temporarily restore normal terminal mode for input
        print(TerminalControl.showCursor, terminator: "")
        terminalConfig.disableRawMode()
        await handleMenuSelection(selectedOption, store: store)
        terminalConfig.enableRawMode()
        print(TerminalControl.hideCursor, terminator: "")
        
    default:
        break
    }

}
