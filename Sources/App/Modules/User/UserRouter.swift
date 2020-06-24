import Vapor
import ViperKit

struct UserRouter: ViperRouter {
	let apiController = UserApiController()

	func boot(routes: RoutesBuilder, app: Application) throws {

		let api = routes.grouped("api", "user")
		api.grouped(UserModelCredentialsAuthenticator())
			.post("login", use: apiController.login)
		api.post("sign-in-with-apple", use: apiController.signInWithApple)
	}
}
