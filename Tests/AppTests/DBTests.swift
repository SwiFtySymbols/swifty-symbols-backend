@testable import App
import Spec
import Fluent
import SwiFtySymbolsShared

final class DBTests: AppTestCase {
	func testLoadingDuplicateDataIsIdempotent() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let expectedModelCount = try SymbolModel.query(on: app.db).count().wait()
		let expectedTagCount = try SymbolTag.query(on: app.db).count().wait()
		let expectedConnectionCount = try SymbolTagConnection.query(on: app.db).count().wait()

		let seed = UtilitySeedDatabase { () -> [UtilitySeedDatabase.SymbolSeedValue] in
			try self.getSourceTestSymbols(for: app)
		}

		try seed.seedDB(app.db)

		let modelCount = try SymbolModel.query(on: app.db).count().wait()
		let tagCount = try SymbolTag.query(on: app.db).count().wait()
		let connectionCount = try SymbolTagConnection.query(on: app.db).count().wait()

		XCTAssertEqual(expectedModelCount, modelCount)
		XCTAssertEqual(expectedTagCount, tagCount)
		XCTAssertEqual(expectedConnectionCount, connectionCount)
	}
}
