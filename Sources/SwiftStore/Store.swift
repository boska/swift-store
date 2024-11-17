import SwiftUI

public protocol StateType: Equatable {
  associatedtype Action
}

public protocol Store {
  associatedtype State: StateType

  var state: State { get }
  func dispatch(_ action: State.Action) async
}

public typealias Middleware<State: StateType> = (
  _ store: any Store,
  _ next: @escaping (State.Action) async -> Void,
  _ action: State.Action
) async -> Void

public final class CoreStore<State: StateType>: Store {
  private let reducer: (State, State.Action) -> State
  private let middleware: [Middleware<State>]
	public var state: State {
		_state
	}
  private(set) var _state: State
  private var stateHistory: [State] = []
  private let maxHistoryItems: Int

  public init(
    initialState: State,
    reducer: @escaping (State, State.Action) -> State,
    middleware: [Middleware<State>] = [],
    maxHistoryItems: Int = 10
  ) {
    self.maxHistoryItems = maxHistoryItems
    self._state = initialState
    self.reducer = reducer
    self.middleware = middleware
  }

	public func dispatch(_ action: State.Action) async {
    // Save current state before modification
    stateHistory.append(_state)
    if stateHistory.count > maxHistoryItems {
      stateHistory.removeFirst()
    }

    // Create the middleware chain
    let chain = middleware.reduce(
      { [weak self] action in
        guard let self = self else { return }
        self._state = self.reducer(self._state, action)
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
    _state = previousState
  }

  var canUndo: Bool {
    !stateHistory.isEmpty
  }
}

@MainActor
public final class ObservableStore<S: Store>: ObservableObject {
	public var state: S.State {
		_state
	}
  @Published private(set) var _state: S.State
  private let store: S

  public init(store: S) {
    self.store = store
    self._state = store.state
  }

	public func dispatch(_ action: S.State.Action) {
    Task {
      await store.dispatch(action)
      await MainActor.run { self._state = store.state }
    }
  }
}