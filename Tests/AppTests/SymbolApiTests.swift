@testable import App
import Spec
import Fluent

final class SymbolApiTests: AppTestCase {

	func testListSymbols() throws {
		let app = try createTestApp()
//		let token = try getAPIToken(app)
		defer { app.shutdown() }

		let sourceSymbols = try getSourceTestSymbols(for: app)

		try app
			.describe("Symbol listing should return ok")
			.get("/api/symbols?per=3000")
			.expect(.ok)
			.expect(.json)
			.expect(Page<SymbolModel.ListItem>.self) { content in
				let expectedSymbolNames = Set(sourceSymbols.map(\.name))
				let aquiredNames = Set(content.items.map(\.value))
				XCTAssertEqual(expectedSymbolNames, aquiredNames)
			}
			.test()
	}

}
