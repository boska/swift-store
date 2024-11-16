import SwiftUI

@MainActor
final class AppStore: ObservableObject {
  @Published private(set) var state: AppState

  private var tasks: [Task<AppAction?, Never>?] = []

  init(initialState: AppState = AppState()) {
    self.state = initialState
  }

  func send(_ action: AppAction) {
    AppReducer.reduce(&state, action: action)
    tasks.append(onChange(oldState: state, newState: state))
  }

  deinit {
    tasks.forEach { $0?.cancel() }
    tasks.removeAll()
  }
}

func onChange(oldState: AppState, newState: AppState) -> Task<AppAction?, Never>? {
  return composeEffects([
    whenChanged(\.colorScheme, debounce: 1.5, perform: handleColorSchemeChange),
    whenChanged(\.tintColor, debounce: 0.2, perform: handleTintColorChange),
    whenChanged(\.chat, perform: handleChatStateChange),
  ])(oldState, newState)
}

// Higher-order function for state change observation
private func whenChanged<T: Equatable>(
  _ keyPath: KeyPath<AppState, T>,
  perform effect: @escaping (T) -> Task<AppAction?, Never>?
) -> StateEffect {
  return { oldState, newState in
    guard oldState[keyPath: keyPath] != newState[keyPath: keyPath] else { return nil }
    return effect(newState[keyPath: keyPath])
  }
}

// Debounced version for UI-related changes
private func whenChanged<T: Equatable>(
  _ keyPath: KeyPath<AppState, T>,
  debounce seconds: Double,
  perform effect: @escaping (T) -> Task<AppAction?, Never>?
) -> StateEffect {
  return { oldState, newState in
    guard oldState[keyPath: keyPath] != newState[keyPath: keyPath] else { return nil }
    return Task {
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      return await effect(newState[keyPath: keyPath])?.value
    }
  }
}

// Example effect handlers
private func handleColorSchemeChange(_ scheme: ColorScheme) -> Task<AppAction?, Never>? {
  return Task {
    UserDefaults.standard.set(scheme == .dark, forKey: "isDarkMode")
    return nil
  }
}

private func handleTintColorChange(_ color: Color) -> Task<AppAction?, Never>? {
  return Task {
    // Handle tint color changes, maybe save to UserDefaults
    return nil
  }
}

private func handleChatStateChange(_ chatState: ChatState) -> Task<AppAction?, Never>? {
  return Task {
    // Handle chat state changes
    return nil
  }
}

// Helper for combining effects
private typealias StateEffect = (AppState, AppState) -> Task<AppAction?, Never>?

private func composeEffects(_ effects: [StateEffect]) -> StateEffect {
  return { oldState, newState in
    let tasks = effects.compactMap { $0(oldState, newState) }
    guard !tasks.isEmpty else { return nil }

    return Task {
      for task in tasks {
        if let action = await task.value {
          return action
        }
      }
      return nil
    }
  }
}

// State
struct AppState {
  var colorScheme: ColorScheme = .light
  var tintColor: Color = .blue
  var chat: ChatState = ChatState()
}

struct ChatState: Equatable {
  var messages: [String] = []
  var isLoading: Bool = false
}

// Actions
enum AppAction {
  case setColorScheme(ColorScheme)
  case setTintColor(Color)
  case chat(ChatAction)
}

enum ChatAction {
  case addMessage(String)
  case setLoading(Bool)
}

// Reducer
enum AppReducer {
  static func reduce(_ state: inout AppState, action: AppAction) {
    switch action {
    case .setColorScheme(let scheme):
      state.colorScheme = scheme
    case .setTintColor(let color):
      state.tintColor = color
    case .chat(let chatAction):
      switch chatAction {
      case .addMessage(let message):
        state.chat.messages.append(message)
      case .setLoading(let isLoading):
        state.chat.isLoading = isLoading
      }
    }
  }
}
