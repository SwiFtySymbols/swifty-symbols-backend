@testable import App
import XCTVapor
import Fluent
import FluentSQLiteDriver
import SwiFtySymbolsShared

open class AppTestCase: XCTestCase {
	
	func createTestApp() throws -> Application {
		let app = Application(.testing)
		try configure(app)
		app.databases.use(.sqlite(.memory), as: .sqlite)
		app.databases.default(to: .sqlite)

		try app.autoMigrate().wait()

		let seed = UtilitySeedDatabase { () -> [UtilitySeedDatabase.SymbolSeedValue] in
			try self.getSourceTestSymbols(for: app)
		}

		try seed.seedDB(app.db)

		return app
	}

	func getAPIToken(_ app: Application) throws -> String {

		struct UserTokenResponse: Content {
			let id: String
			let value: String
		}

		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: password)

		let userLogin = UserLoginContext(email: email, password: password)

		try app.test(.POST, "/api/user/signup", beforeRequest: { request in
			try request.content.encode(userCreate)
		}, afterResponse: { response in
			XCTAssertEqual(response.status, .created)
		})


		var token: String?

		try app.test(.POST, "/api/user/login", beforeRequest: { request in
			try request.content.encode(userLogin)
		}, afterResponse: { response in
			XCTAssertContent(UserTokenResponse.self, response) { content in
				token = content.value
			}
		})

		guard let unwrapped = token else {
			XCTFail("Login failed")
			throw Abort(.unauthorized)
		}
		return unwrapped
	}

	func getSourceTestSymbols(for app: Application) throws -> [UtilitySeedDatabase.SymbolSeedValue] {
		let testSymbolJsonSource = URL(fileURLWithPath: app.directory.workingDirectory)
			.appendingPathComponent("Support")
			.appendingPathComponent("testlist")
			.appendingPathExtension("json")

		let data = try Data(contentsOf: testSymbolJsonSource)
		return try JSONDecoder().decode([UtilitySeedDatabase.SymbolSeedValue].self, from: data)
	}
}

extension UserLoginContext: Content {}
