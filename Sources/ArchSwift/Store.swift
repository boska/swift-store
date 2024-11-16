import SwiftUI

// 1. Core protocol that doesn't depend on SwiftUI
protocol Store {
  associatedtype State
  associatedtype Action

  var state: State { get }
  func dispatch(_ action: Action) async
}

// 2. Pure reducer type
protocol Reducer<State, Action> {
  associatedtype State
  associatedtype Action

  func reduce(state: State, action: Action) -> State
}

// 3. Core store implementation
final class CoreStore<R: Reducer>: Store {
  typealias State = R.State
  typealias Action = R.Action

  private let reducer: R
  private(set) var state: State

  init(initialState: State, reducer: R) {
    self.state = initialState
    self.reducer = reducer
  }

  func dispatch(_ action: Action) async {
    state = reducer.reduce(state: state, action: action)
  }
}

// 4. SwiftUI wrapper (only place where @MainActor is needed)
@MainActor
final class ObservableStore<S: Store>: ObservableObject {
  @Published private(set) var state: S.State
  private let store: S

  init(store: S) {
    self.store = store
    self.state = store.state
  }

  func dispatch(_ action: S.Action) {
    Task {
      await store.dispatch(action)
      await MainActor.run { self.state = store.state }
    }
  }
}
