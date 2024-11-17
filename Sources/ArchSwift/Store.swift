import SwiftUI

protocol StateType: Equatable {
  associatedtype Action
}

protocol Store {
  associatedtype State: StateType

  var state: State { get }
  func dispatch(_ action: State.Action) async
}

typealias Middleware<State: StateType> = (
  _ store: any Store,
  _ next: @escaping (State.Action) async -> Void,
  _ action: State.Action
) async -> Void

final class CoreStore<State: StateType>: Store {
  private let reducer: (State, State.Action) -> State
  private let middleware: [Middleware<State>]
  private(set) var state: State
  private var stateHistory: [State] = []
  private let maxHistoryItems: Int

  init(
    initialState: State,
    reducer: @escaping (State, State.Action) -> State,
    middleware: [Middleware<State>] = [],
    maxHistoryItems: Int = 10
  ) {
    self.maxHistoryItems = maxHistoryItems
    self.state = initialState
    self.reducer = reducer
    self.middleware = middleware
  }

  func dispatch(_ action: State.Action) async {
    // Save current state before modification
    stateHistory.append(state)
    if stateHistory.count > maxHistoryItems {
      stateHistory.removeFirst()
    }

    // Create the middleware chain
    let chain = middleware.reduce(
      { [weak self] action in
        guard let self = self else { return }
        self.state = self.reducer(self.state, action)
      } as @Sendable (State.Action) async -> Void
    ) { chain, middleware in
      return { [weak self] action in
        guard let self = self else { return }
        await middleware(self, chain, action)
      }
    }

    // Start the chain
    await chain(action)
  }

  func undo() async {
    guard let previousState = stateHistory.popLast() else { return }
    state = previousState
  }

  var canUndo: Bool {
    !stateHistory.isEmpty
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
