@testable import App
import Spec
import Fluent
import SwiFtySymbolsShared

final class SymbolApiTests: AppTestCase {

	func getSymbolID(for symbol: String, on app: Application) throws -> UUID? {
		var symbolID: UUID?
		try app
			.describe("Get symbol ID for future use")
			.get("/api/symbols?per=3000")
			.expect(.ok)
			.expect(.json)
			.expect(Page<SymbolModel.ListItem>.self) { content in
				let symbol = content.items.first { $0.value == symbol }
				symbolID = symbol?.id
			}
			.test()

		return symbolID
	}

	func testListSymbols() throws {
		let app = try createTestApp()
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

	func testGetSymbol() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let expectedSymbol = "arrow.triangle.2.circlepath.circle"
		let symbolID = try getSymbolID(for: expectedSymbol, on: app)

		try app
			.describe("Get single symbol")
			.get("/api/symbols/\(symbolID!)")
			.expect(.ok)
			.expect(.json)
			.expect(SymbolModel.GetContent.self) { content in
				XCTAssertEqual(expectedSymbol, content.value)
				XCTAssertEqual(.two, content.availability)
				XCTAssertEqual([], content.localizations)
				XCTAssertEqual(["arrow.2.circlepath.circle"], content.deprecatedNames)
			}
			.test()
	}

	func testCreateTag() throws {
		let app = try createTestApp()
		let token = try getAPIToken(app)
		defer { app.shutdown() }

		let tagString = "test.tag"
		let expectedSymbol = "arrow.triangle.2.circlepath.circle"
		let symbolID = try getSymbolID(for: expectedSymbol, on: app)

		let createTag = SFTagSymbolRequest(symbolID: symbolID!, tagValue: tagString)

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

	func testSearch() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let searchString = "fill"
		let expectedResults = Set(["app.fill",
							   "square.fill.on.circle.fill",
							   "33.square.fill",
							   "lock.slash.fill",
							   "9.alt.circle.fill",
							   "minus.diamond.fill",
							   "headphones.circle.fill",
							   "arrow.left.circle.fill",
							   "location.north.line.fill",
							   "arrow.up.left.and.arrow.down.right.circle.fill"])

		try app
			.describe("Searching should return the correct results.")
			.get("/api/symbols/search?searchQuery=\(searchString)")
			.expect(.ok)
			.expect(.json)
			.expect([SFSymbolResultObject].self) { content in
				let results = Set(content.map(\.value))
				XCTAssertEqual(expectedResults, results)
				XCTAssertEqual(0.5, content.first?.resultScore)
			}
			.test()
	}

}
