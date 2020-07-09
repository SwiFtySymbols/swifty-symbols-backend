@testable import App
import Spec
import Fluent
import SwiFtySymbolsShared

final class UserApiTests: AppTestCase {

	// MARK: - account creation
	func testUserCreation() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: password)

		try app
			.describe("Creating an account should respond `created`")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.created)
			.test()
	}

	func testUserCreationPasswordMismatch() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: String(password.reversed()))

		try app
			.describe("Passwords should be validated to match.")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.badRequest)
			.test()
	}

	func testUserCreationDuplicate() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: password)

		try app
			.describe("Passwords should be validated to match.")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.created)
			.test()

		try app
			.describe("A new account should not be created.")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.internalServerError)
			.test()
	}

	// MARK: - login

	func testUserLogin() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		struct UserTokenResponse: Content {
			let id: String
			let value: String
		}

		// create user
		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: password)

		try app
			.describe("Creating an account should respond `created`")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.created)
			.test()

		// login test
		let userLogin = UserLoginContext(email: email, password: password)

		try app
			.describe("Logging into an account should respond with a token.")
			.post("/api/user/login")
			.body(userLogin)
			.expect(.ok)
			.expect(UserTokenResponse.self)
			.test()
	}

	func testUserBadPassword() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		// create user
		let email = "he@ho.hum"
		let password = "Abc123!"
		let userCreate = UserCreateContext(email: email, password: password, passwordVerify: password)

		try app
			.describe("Creating an account should respond `created`")
			.post("/api/user/signup")
			.body(userCreate)
			.expect(.created)
			.test()

		// login test
		let userLogin = UserLoginContext(email: email, password: String(password.reversed()))

		try app
			.describe("Logging into an account should respond with a token.")
			.post("/api/user/login")
			.body(userLogin)
			.expect(.unauthorized)
			.test()
	}

	func testUserNotExist() throws {
		let app = try createTestApp()
		defer { app.shutdown() }

		// login test
		let email = "he@ho.hum"
		let password = "Abc123!"
		let userLogin = UserLoginContext(email: email, password: password)

		try app
			.describe("Logging into an account should respond with a token.")
			.post("/api/user/login")
			.body(userLogin)
			.expect(.unauthorized)
			.test()
	}

}
