import Vapor
import Fluent
import ContentApi

struct SymbolModelApiController: ListContentController, GetContentController {
	typealias Model = SymbolModel

	func get(_ req: Request) throws -> EventLoopFuture<Model.GetContent> {
		let id = UUID(uuidString: req.parameters.get("id") ?? "") ?? UUID()
		return try get(id, on: req)
	}

	func get(_ symbolID: UUID, on req: Request) throws -> EventLoopFuture<Model.GetContent> {
		return SymbolModel.query(on: req.db)
			.filter(\.$id == symbolID)
			.with(\.$connections) { connection in
				connection.with(\.$tag)
			}
			.first()
			.unwrap(or: Abort(.badRequest))
			.map(\.getContent)
	}
}
