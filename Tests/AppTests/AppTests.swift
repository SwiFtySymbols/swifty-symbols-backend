@testable import App
import Fluent
import XCTVapor

final class AppTests: XCTestCase {
    func testStub() throws {
        XCTAssert(true)
    }

    static let allTests = [
        ("testStub", testStub),
    ]
}

extension DatabaseID {

}
