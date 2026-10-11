import Combine
import XCTest
import TimeatoKit

/// Records the update checks. It does not check for updates.
@MainActor
private final class FakeUpdateProvider: UpdateProvider {
    let canCheck = CurrentValueSubject<Bool, Never>(false)
    var checkCount = 0

    var canCheckForUpdates: AnyPublisher<Bool, Never> { canCheck.eraseToAnyPublisher() }

    func checkForUpdates() { checkCount += 1 }
}

@MainActor
final class CheckForUpdatesViewModelTests: XCTestCase {
    func testFollowsTheProvider() {
        let provider = FakeUpdateProvider()
        let model = CheckForUpdatesViewModel(provider: provider)
        XCTAssertFalse(model.canCheckForUpdates)

        provider.canCheck.send(true)
        XCTAssertTrue(model.canCheckForUpdates)

        provider.canCheck.send(false)
        XCTAssertFalse(model.canCheckForUpdates)
    }

    func testCheckForUpdatesCallsTheProvider() {
        let provider = FakeUpdateProvider()
        let model = CheckForUpdatesViewModel(provider: provider)

        model.checkForUpdates()

        XCTAssertEqual(provider.checkCount, 1)
    }
}
