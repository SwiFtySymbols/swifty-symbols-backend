import Vapor
import ViperKit

struct SymbolRouter: ViperRouter {
	
	let symbolController = SymbolModelApiController()
	
	func boot(routes: RoutesBuilder, app: Application) throws {
		let publicApi = routes.grouped("api")
		let privateApi = publicApi.grouped([
			UserTokenModel.authenticator(),
			UserModel.guardMiddleware()
		])

		symbolController.setupListRoute(routes: publicApi.grouped("symbols"))
	}
}
