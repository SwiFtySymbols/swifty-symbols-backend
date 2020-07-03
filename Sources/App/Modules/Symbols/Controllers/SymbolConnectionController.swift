import Vapor
import Fluent

struct SymbolConnectionController {

	func getConnectionBetween(symbolID: UUID, andTagID tagID: UUID, req: Request) -> EventLoopFuture<SymbolTagConnection?> {
		return SymbolTagConnection.query(on: req.db)
			.filter(\.$symbol.$id == symbolID)
			.filter(\.$tag.$id == tagID)
			.first()
	}

	func connectTag(_ req: Request) throws -> EventLoopFuture<SymbolModel.GetContent> {
		struct ConnectRequest: Content {
			let symbolID: UUID
			let tagValue: String
		}

		let user = try req.auth.require(UserModel.self)

		let connectReference = try req.content.decode(ConnectRequest.self)

		let symbol = SymbolModel.query(on: req.db)
			.filter(\.$id == connectReference.symbolID)
			.first()
			.unwrap(or: Abort(.badRequest))

		return symbol.flatMap { symbol -> EventLoopFuture<SymbolModel.GetContent> in
			let tag = SymbolTag.query(on: req.db)
				.filter(\.$value == connectReference.tagValue)
				.first()
				.flatMap { optTag -> EventLoopFuture<SymbolTag> in
					if let tag = optTag {
						return req.eventLoop.future(tag)
					} else {
						let tag = SymbolTag(value: connectReference.tagValue)
						return tag.create(on: req.db)
							.transform(to: tag)
					}
				}

			let connection = tag.flatMap { tag -> EventLoopFuture<SymbolTagConnection?> in
				return getConnectionBetween(
					symbolID: connectReference.symbolID,
					andTagID: tag.id!,
					req: req)
			}
			.flatMap { optConnection -> EventLoopFuture<SymbolTagConnection> in
				if let connection = optConnection {
					// FIXME: vulnerable to manipulation. use unique recommended by to check if
					connection.score += 1
					return connection.update(on: req.db)
						.transform(to: connection)
				} else {
					//create connection
					return tag.flatMap { tag -> EventLoopFuture<SymbolTagConnection> in
						let connection = SymbolTagConnection(tagID: tag.id!,
															 symbolID: connectReference.symbolID,
															 createdBy: user.id!)
						return connection.create(on: req.db)
							.flatMap { req.eventLoop.future(connection) }
					}
				}
			}

			return connection.flatMap { _ -> EventLoopFuture<SymbolModel.GetContent> in
				let loads = symbol.$connections.load(on: req.db)
					.flatMap { _ -> EventLoopFuture<Void> in
						let tagLoads = symbol.connections.map { connection in
							connection.$tag.load(on: req.db)
						}
						return req.eventLoop.flatten(tagLoads)
					}

				return loads.flatMap { _ in
					let tags = symbol.$connections.value?
						.map(\.$tag.value?.listContent)
						.compactMap({ $0 })

					var getContent = symbol.getContent
					getContent.tags = tags
					return req.eventLoop.future(getContent)
				}
			}
		}
	}
}
