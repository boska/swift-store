public protocol StateType: Equatable {
  associatedtype Action
}

public protocol StoreProtocol {
  associatedtype State: StateType

  // Async accessors so implementations can be actors or otherwise isolated.
  func getState() async -> State
  func canUndo() async -> Bool

  // Dispatch and undo remain async to allow middleware and async effects.
  func dispatch(_ action: State.Action) async
  func undo() async
}

// Middleware receives an async getState closure so it can observe the latest state
// from an isolated implementation (for example, an actor). dispatch/next remain async.
public typealias Middleware<State: StateType> = (
  _ getState: @escaping () async -> State,
  _ dispatch: @escaping (State.Action) async -> Void,
  _ next: @escaping (State.Action) async -> Void,
  _ action: State.Action
) async -> Void

// Actor-based CoreStore to get automatic concurrency safety.
// Conforms to StoreProtocol via async getters for state/canUndo.
public actor CoreStore<State: StateType>: StoreProtocol {
  private let reducer: (State, State.Action) -> State
  private let middleware: [Middleware<State>]
  private var _state: State
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

  // Async getter for state (suitable for actor isolation).
  public func getState() async -> State {
    return _state
  }

  public func canUndo() async -> Bool {
    !stateHistory.isEmpty
  }

  public func dispatch(_ action: State.Action) async {
    // Save current state for undo
    stateHistory.append(_state)
    if stateHistory.count > maxHistoryItems {
      stateHistory.removeFirst()
    }

    // Base chain: apply reducer to update internal state.
    var chain: (State.Action) async -> Void = { action in
      self._state = self.reducer(self._state, action)
    }

    // Build middleware chain in reverse so first middleware runs first.
    for mw in middleware.reversed() {
      let next = chain
      chain = { action in
        await mw(
          { await self.getState() },
          { action in await self.dispatch(action) },
          next,
          action
        )
      }
    }

    // Start the chain
    await chain(action)
  }

  public func undo() async {
    guard let previous = stateHistory.popLast() else { return }
    _state = previous
  }
}