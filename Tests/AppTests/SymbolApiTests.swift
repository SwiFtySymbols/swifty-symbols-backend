@testable import App
import Spec
import Fluent
import SwiFtySymbolsShared

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

	func testCreateTag() throws {
		let app = try createTestApp()
		let token = try getAPIToken(app)
		defer { app.shutdown() }

		let tagString = "test.tag"
		let expectedSymbol = "arrow.triangle.2.circlepath.circle"
		var myID: UUID?

		try app
			.describe("Get symbol ID for use")
			.get("/api/symbols?per=3000")
			.expect(.ok)
			.expect(.json)
			.expect(Page<SymbolModel.ListItem>.self) { content in
				let symbol = content.items.first { $0.value == expectedSymbol }
				myID = symbol?.id
			}
			.test()

		let createTag = SFTagSymbolRequest(symbolID: myID!, tagValue: tagString)

		try app
			.describe("Creating a tag should return created")
			.bearerToken(token)
			.body(createTag)
			.post("/api/symbols/tag")
			.expect(.created)
			.expect(.json)
			.expect(SymbolModel.GetContent.self) { content in
				let tag = content.tags?.first(where: { $0.value == tagString })
				XCTAssertEqual(tag?.value, tagString)
				XCTAssertEqual(expectedSymbol, content.value)
			}
			.test()
	}

}
