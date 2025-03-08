public protocol StateType: Equatable {
  associatedtype Action
}

public protocol StoreProtocol {
  associatedtype State: StateType

  var state: State { get }
  var canUndo: Bool { get }
  func dispatch(_ action: State.Action) async
  func undo() async
}

public typealias Middleware<State: StateType> = (
  _ getState: @escaping () -> State,
  _ dispatch: @escaping (State.Action) async -> Void,
  _ next: @escaping (State.Action) async -> Void,
  _ action: State.Action
) async -> Void

public final class CoreStore<State: StateType>: StoreProtocol {
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
        await middleware(
          { self.state },
          { await self.dispatch($0) },
          chain,
          action
        )
      }
    }

    // Start the chain
    await chain(action)
  }

  public func undo() async {
    guard let previousState = stateHistory.popLast() else { return }
    _state = previousState
  }

  public var canUndo: Bool {
    !stateHistory.isEmpty
  }
}
