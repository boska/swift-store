import XCTest

@testable import ArchSwift

final class StoreTests: XCTestCase {
  struct TestState: StateType {
    var counter: Int = 0

    enum Action {
      case increment
      case decrement
      case double
    }
  }

  func testBasicStoreOperations() async {
    // Given
    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in
        var newState = state
        switch action {
        case .increment:
          newState.counter += 1
        case .decrement:
          newState.counter -= 1
        case .double:
          newState.counter *= 2
        }
        return newState
      }
    )

    // When
    await store.dispatch(.increment)

    // Then
    XCTAssertEqual(store.state.counter, 1)

    // And when
    await store.dispatch(.decrement)

    // Then
    XCTAssertEqual(store.state.counter, 0)
  }

  func testMiddleware() async {
    // Given
    let loggingMiddleware: (TestState, TestState.Action) async -> TestState.Action? = {
      state, action in
      print("Action: \(action), State: \(state)")
      return action
    }

    let doubleToIncrementMiddleware: (TestState, TestState.Action) async -> TestState.Action? = {
      _, action in
      if case .double = action {
        return .increment  // Transform double into increment
      }
      return action
    }

    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in
        var newState = state
        switch action {
        case .increment:
          newState.counter += 1
        case .decrement:
          newState.counter -= 1
        case .double:
          newState.counter *= 2
        }
        return newState
      },
      middleware: [
        loggingMiddleware,
        doubleToIncrementMiddleware,
      ]
    )

    // When
    await store.dispatch(TestState.Action.double)

    // Then
    XCTAssertEqual(store.state.counter, 1)  // double was transformed to increment
  }
}
