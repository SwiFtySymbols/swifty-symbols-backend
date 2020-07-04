import Vapor
import ViperKit

struct SymbolRouter: ViperRouter {
	
	let symbolController = SymbolModelApiController()
	let connectionController = SymbolConnectionController()
	
	func boot(routes: RoutesBuilder, app: Application) throws {
		let publicApi = routes.grouped("api")
		let privateApi = publicApi.grouped([
			UserTokenModel.authenticator(),
			UserModel.guardMiddleware()
		])

		let publicSymbolsApi = publicApi.grouped("symbols")
		let privateSymbolsApi = privateApi.grouped("symbols")

		symbolController.setupListRoute(routes: publicSymbolsApi)
		symbolController.setupGetRoute(routes: publicSymbolsApi)

		privateSymbolsApi.post("tag", use: connectionController.connectTag)
		publicSymbolsApi.get("search", use: connectionController.search)
	}
}
