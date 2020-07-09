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

		try app
			.describe("Creating an account should respond `created`")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.created)
			.test()

		var token: String?

		try app
			.describe("Logging into an account should respond with a token.")
			.post("/api/user/login")
			.body(userLogin)
			.expect(.ok)
			.expect(UserTokenResponse.self) { tokenResponse in
				token = tokenResponse.value
			}
			.test()

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
