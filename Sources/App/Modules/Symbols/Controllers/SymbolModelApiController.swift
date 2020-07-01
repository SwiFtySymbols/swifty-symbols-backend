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
			.flatMapThrowing({ model -> EventLoopFuture<Model.GetContent> in
				guard let model = model else { throw Abort(.badRequest) }
				let tags = model.$connections.value?
					.map(\.$tag.value?.listContent)
					.compactMap({ $0 })
				var getContent = model.getContent
				getContent.tags = tags
				return req.eventLoop.future(getContent)
			})
			.flatMap { $0 }
	}

}
