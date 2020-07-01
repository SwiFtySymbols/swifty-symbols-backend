import Vapor
import Fluent
import ContentApi

struct SymbolModelApiController: ListContentController, GetContentController {
	typealias Model = SymbolModel

	func get(_ req: Request) throws -> EventLoopFuture<Model.GetContent> {
		let id = UUID(uuidString: req.parameters.get("id") ?? "") ?? UUID()
		return SymbolModel.query(on: req.db)
			.filter(\.$id == id)
			.with(\.$connections) { connection in
				connection.with(\.$tag)
			}
			.first()
			.unwrap(or: Abort(.badRequest))
			.map({ model in
				let tags = model.$connections.value?
					.map(\.$tag.value?.listContent)
					.compactMap({ $0 })
				var getContent = model.getContent
				getContent.tags = tags
				return getContent
			})
	}

}
