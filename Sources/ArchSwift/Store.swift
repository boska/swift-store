import SwiftUI

protocol StateType: Equatable {
  associatedtype Action
}

protocol Store {
  associatedtype State: StateType

  var state: State { get }
  func dispatch(_ action: State.Action) async
}

final class CoreStore<State: StateType>: Store {
  private let reducer: (State, State.Action) -> State
  private let middleware: [(State, State.Action) async -> State.Action?]
  private(set) var state: State

  init(
    initialState: State,
    reducer: @escaping (State, State.Action) -> State,
    middleware: [(State, State.Action) async -> State.Action?] = []
  ) {
    self.state = initialState
    self.reducer = reducer
    self.middleware = middleware
  }

  func dispatch(_ action: State.Action) async {
    // Run through middleware chain
    var currentAction = action
    for middlewareItem in middleware {
      guard let newAction = await middlewareItem(state, currentAction) else {
        return  // Middleware cancelled the action
      }
      currentAction = newAction
    }

    // Apply final action
    state = reducer(state, currentAction)
  }
}

@MainActor
final class ObservableStore<S: Store>: ObservableObject {
  @Published private(set) var state: S.State
  private let store: S

  init(store: S) {
    self.store = store
    self.state = store.state
  }

  func dispatch(_ action: S.State.Action) {
    Task {
      await store.dispatch(action)
      await MainActor.run { self.state = store.state }
    }
  }
}
