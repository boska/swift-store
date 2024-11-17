import XCTest

@testable import ArchSwift

final class StoreTests: XCTestCase {
  struct TestState: StateType {
    var counter: Int = 0

    enum Action {
      case increment
      case decrement
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
        }
        return newState
      }
    )

    // When
    await store.dispatch(.increment)

    // Then
    XCTAssertEqual(store.state.counter, 1)

    // When
    await store.dispatch(.decrement)

    // Then
    XCTAssertEqual(store.state.counter, 0)
  }

  func testMiddleware() async {
    var middlewareCalled = false

    // Given
    let testMiddleware: Middleware<TestState> = { store, next, action in
      middlewareCalled = true
      await next(action)
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
        }
        return newState
      },
      middleware: [testMiddleware]
    )

    // When
    await store.dispatch(.increment)

    // Then
    XCTAssertTrue(middlewareCalled)
    XCTAssertEqual(store.state.counter, 1)
  }
}
