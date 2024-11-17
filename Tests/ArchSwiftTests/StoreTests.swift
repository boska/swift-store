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

    // And when
    await store.dispatch(.decrement)

    // Then
    XCTAssertEqual(store.state.counter, 0)
  }
}
