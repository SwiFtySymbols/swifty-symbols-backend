import Vapor
import Fluent
import SwiFtySymbolsShared

struct SymbolConnectionController {
	static let searchQueryParameter = "searchQuery"

	func getConnectionBetween(symbolID: UUID, andTagID tagID: UUID, request: Request) -> EventLoopFuture<SymbolTagConnection?> {
		return SymbolTagConnection.query(on: request.db)
			.filter(\.$symbol.$id == symbolID)
			.filter(\.$tag.$id == tagID)
			.first()
	}

	func getConnectionBetween(symbol: EventLoopFuture<SymbolModel>, andTag tag: EventLoopFuture<SymbolTag>, request: Request) -> EventLoopFuture<SymbolTagConnection?> {
		return symbol.flatMap { symbolModel in
			return tag.flatMap { tagModel in
				return self.getConnectionBetween(symbolID: symbolModel.id!, andTagID: tagModel.id!, request: request)
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

		guard connectReference.validate() else {
			throw Abort(.badRequest)
		}

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

	func search(_ req: Request) throws -> EventLoopFuture<[SFSymbolResultObject]> {
		guard let query = req.query[String.self, at: Self.searchQueryParameter] else {
			throw Abort(.badRequest)
		}

		let terms = query
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
			.split(separator: " ")
			.map { String($0) }

		struct SearchScore: Hashable {
			let tag: SymbolModel
			let score: Int
		}

		typealias SymbolScore = [SymbolModel: Double]

		func queryFirstTerm(in terms: [String], combined: EventLoopFuture<SymbolScore>) -> EventLoopFuture<SymbolScore> {
			guard let firstItem = terms.first else { return combined }

			let tagMatch = SymbolTag.query(on: req.db)
				.filter(\.$value ~~ firstItem)
				.with(\.$connections) { connection in
					connection.with(\.$symbol)
				}
				.limit(256)
				.all()

			let termCount = Double(firstItem.count)
			return combined.flatMap { (combinedDict: SymbolScore) -> EventLoopFuture<SymbolScore> in
				tagMatch.map { (tags: [SymbolTag]) -> SymbolScore in
					var newCombined = combinedDict
					for tag in tags {
						let score = termCount / Double(tag.value.count)
						let symbols = tag.connections.map(\.symbol)
						for symbol in symbols {
							newCombined[symbol, default: 0] += score
						}
					}
					return newCombined
				}
			}
		}

		let combinedStarter = req.eventLoop.future(SymbolScore())
		let scores = queryFirstTerm(in: terms, combined: combinedStarter)

		return scores.map { scores -> [SFSymbolResultObject] in
			var results: [SFSymbolResultObject] = []
			for (symbol, score) in scores {
				let result = SFSymbolResultObject(id: symbol.id!, value: symbol.name, availability: symbol.availability, resultScore: score)
				results.append(result)
			}
			return results.sorted { $0.resultScore > $1.resultScore }
		}
	}
}
