import XCTest

@testable import ArchSwift

final class StoreTests: XCTestCase {
  struct TestState {
    var counter: Int = 0
  }

  enum TestAction {
    case increment
    case decrement
  }

  struct TestReducer: Reducer {
    func reduce(state: TestState, action: TestAction) -> TestState {
      var newState = state
      switch action {
      case .increment:
        newState.counter += 1
      case .decrement:
        newState.counter -= 1
      }
      return newState
    }
  }

  func testBasicStoreOperations() async {
    // Given
    let store = CoreStore(initialState: TestState(), reducer: TestReducer())

    // When
    await store.dispatch(.increment)

    // Then
    XCTAssertEqual(store.state.counter, 1)

    // And when
    await store.dispatch(.decrement)

    // Then
    XCTAssertEqual(store.state.counter, 0)
  }
}
