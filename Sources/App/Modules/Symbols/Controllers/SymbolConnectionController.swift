import Vapor
import Fluent
import SwiFtySymbolsShared

struct SymbolConnectionController {

	func getConnectionBetween(symbolID: UUID, andTagID tagID: UUID, request: Request) -> EventLoopFuture<SymbolTagConnection?> {
		return SymbolTagConnection.query(on: request.db)
			.filter(\.$symbol.$id == symbolID)
			.filter(\.$tag.$id == tagID)
			.first()
	}

	func getConnectionBetween(symbol: EventLoopFuture<SymbolModel>, andTag tag: EventLoopFuture<SymbolTag>, request: Request) -> EventLoopFuture<SymbolTagConnection?> {
		return symbol.flatMap { symbolModel in
			return tag.flatMap { tagModel in
				return getConnectionBetween(symbolID: symbolModel.id!, andTagID: tagModel.id!, request: request)
			}
		}
	}

	/// Retrieves existing tag from database if it exists, creating it if it doesnt.
	func getCreateTag(named value: String, request: Request) -> EventLoopFuture<SymbolTag> {
		return SymbolTag.query(on: request.db)
			.filter(\.$value == value)
			.first()
			.flatMap { optTag -> EventLoopFuture<SymbolTag> in
				if let tag = optTag {
					return request.eventLoop.future(tag)
				} else {
					let tag = SymbolTag(value: value)
					return tag.create(on: request.db)
						.transform(to: tag)
				}
			}
	}

	func connectTag(_ req: Request) throws -> EventLoopFuture<SymbolModel.GetContent> {
		let user = try req.auth.require(UserModel.self)

		let connectReference = try req.content.decode(SFTagSymbolRequest.self)

		let symbol = SymbolModel.query(on: req.db)
			.filter(\.$id == connectReference.symbolID)
			.first()
			.unwrap(or: Abort(.badRequest))

		let tag = getCreateTag(named: connectReference.tagValue, request: req)

		let connection = getConnectionBetween(symbol: symbol, andTag: tag, request: req)
			.flatMap { optConnection -> EventLoopFuture<SymbolTagConnection> in
				// this is explicitly to CREATE a connection. if one already exists, abort
				guard optConnection == nil else {
					return req.eventLoop.future(error: Abort(.conflict))
				}
				//create connection
				return tag.flatMap { tag -> EventLoopFuture<SymbolTagConnection> in
					let connection = SymbolTagConnection(tagID: tag.id!,
														 symbolID: connectReference.symbolID,
														 createdBy: user.id!)
					return connection.create(on: req.db)
						.flatMap { req.eventLoop.future(connection) }
				}
			}

		return symbol.flatMap { symbolModel -> EventLoopFuture<SymbolModel.GetContent> in
			return connection.flatMap { _ -> EventLoopFuture<SymbolModel.GetContent> in
				let loads = symbolModel.$connections.load(on: req.db)
					.flatMap { _ -> EventLoopFuture<Void> in
						let tagLoads = symbolModel.connections.map { connection in
							connection.$tag.load(on: req.db)
						}
						return req.eventLoop.flatten(tagLoads)
					}

				return loads.flatMap { _ in
					let tags = symbolModel.$connections.value?
						.map(\.$tag.value?.listContent)
						.compactMap({ $0 })

					var getContent = symbolModel.getContent
					getContent.tags = tags
					return req.eventLoop.future(getContent)
				}
			}
		}
	}
}

extension SFTagSymbolRequest: Content {}
