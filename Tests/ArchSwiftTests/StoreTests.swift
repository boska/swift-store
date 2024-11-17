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

  func testMultipleMiddleware() async {
    var executionOrder: [String] = []

    let firstMiddleware: Middleware<TestState> = { store, next, action in
      executionOrder.append("first")
      await next(action)
      executionOrder.append("first-end")
    }

    let secondMiddleware: Middleware<TestState> = { store, next, action in
      executionOrder.append("second")
      await next(action)
      executionOrder.append("second-end")
    }

    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in state },
      middleware: [firstMiddleware, secondMiddleware]
    )

    await store.dispatch(.increment)

    // Middleware executes from last to first (outside to inside)
    // secondMiddleware wraps firstMiddleware, which wraps the reducer
    XCTAssertEqual(executionOrder, ["second", "first", "first-end", "second-end"])
  }

  func testActionTransformingMiddleware() async {
    // Middleware that converts increment to decrement
    let transformMiddleware: Middleware<TestState> = { store, next, action in
      switch action {
      case .increment:
        await next(.decrement)
      default:
        await next(action)
      }
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
      middleware: [transformMiddleware]
    )

    await store.dispatch(.increment)
    // Should decrease because middleware transformed increment to decrement
    XCTAssertEqual(store.state.counter, -1)
  }

  func testAsyncMiddleware() async {
    var asyncOperationCompleted = false

    let asyncMiddleware: Middleware<TestState> = { store, next, action in
      // Simulate async operation
      try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
      asyncOperationCompleted = true
      await next(action)
    }

    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in state },
      middleware: [asyncMiddleware]
    )

    await store.dispatch(.increment)
    XCTAssertTrue(asyncOperationCompleted)
  }

  func testFilteringMiddleware() async {
    var reducerCalled = false

    let filterMiddleware: Middleware<TestState> = { store, next, action in
      switch action {
      case .increment:
        // Don't call next, effectively blocking the action
        break
      case .decrement:
        await next(action)
      }
    }

    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in
        reducerCalled = true
        return state
      },
      middleware: [filterMiddleware]
    )

    // This action should be blocked
    await store.dispatch(.increment)
    XCTAssertFalse(reducerCalled)

    // This action should go through
    await store.dispatch(.decrement)
    XCTAssertTrue(reducerCalled)
  }

  func testStateAccessInMiddleware() async {
    let stateCheckMiddleware: Middleware<TestState> = { store, next, action in
      // Only allow increment if counter is less than 2
      if case .increment = action {
        guard let counter = store.state as? TestState, counter.counter < 2 else { return }
      }
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
      middleware: [stateCheckMiddleware]
    )

    // First two increments should work
    await store.dispatch(TestState.Action.increment)
    XCTAssertEqual(store.state.counter, 1)
    await store.dispatch(TestState.Action.increment)
    XCTAssertEqual(store.state.counter, 2)
    // Third increment should be blocked
    await store.dispatch(TestState.Action.increment)
    XCTAssertEqual(store.state.counter, 2)
  }

  func testLoggingMiddleware() async {
    var loggedActions: [TestState.Action] = []

    let loggingMiddleware: Middleware<TestState> = { store, next, action in
      loggedActions.append(action)
      await next(action)
    }

    let store = CoreStore(
      initialState: TestState(),
      reducer: { state, action in state },
      middleware: [loggingMiddleware]
    )

    await store.dispatch(.increment)
    await store.dispatch(.decrement)
    await store.dispatch(.increment)

    XCTAssertEqual(loggedActions, [.increment, .decrement, .increment])
  }

  func testUndo() async {
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
    XCTAssertEqual(store.state.counter, 1)
    XCTAssertTrue(store.canUndo)

    await store.dispatch(.increment)
    XCTAssertEqual(store.state.counter, 2)

    // Then
    await store.undo()
    XCTAssertEqual(store.state.counter, 1)

    await store.undo()
    XCTAssertEqual(store.state.counter, 0)

    // When trying to undo with empty history
    await store.undo()
    XCTAssertEqual(store.state.counter, 0)
    XCTAssertFalse(store.canUndo)
  }

  func testHistoryLimit() async {
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
      },
      maxHistoryItems: 2
    )

    // When performing more actions than history limit
    await store.dispatch(.increment)  // 1
    await store.dispatch(.increment)  // 2
    await store.dispatch(.increment)  // 3

    XCTAssertEqual(store.state.counter, 3)

    // Then can only undo up to history limit
    await store.undo()
    XCTAssertEqual(store.state.counter, 2)

    await store.undo()
    XCTAssertEqual(store.state.counter, 1)

    // No more history available
    await store.undo()
    XCTAssertEqual(store.state.counter, 1)
  }

  func testUndoWithMiddleware() async {
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
    XCTAssertTrue(middlewareCalled)

    middlewareCalled = false
    await store.undo()
    // Then middleware should not be called for undo
    XCTAssertFalse(middlewareCalled)
  }
}
