import Vapor
import Fluent
import SwiFtySymbolsShared

struct SymbolConnectionController {
	static let searchQueryParameter = "searchQuery"

	// MARK: - Symbols
	func createSymbol(named name: String,
					  restriction: String?,
					  availability: SFVersionAvailability,
					  deprecatedNames: [String],
					  localizationOptions: [SFSymbolLocalizationOptions],
					  database: Database) -> EventLoopFuture<SymbolModel> {

		let existingSymbol = getSymbol(named: name, database: database)

		return existingSymbol.flatMap { optModel -> EventLoopFuture<SymbolModel> in
			guard optModel == nil else {
				return database.eventLoop.future(error: Abort(.badRequest, reason: "A Symbol with that name already exists."))
			}
			let symbol = SymbolModel(name: name,
									 restriction: restriction,
									 availability: availability,
									 deprecatedNames: deprecatedNames,
									 localizationOptions: localizationOptions)

			return symbol.create(on: database)
				.transform(to: symbol)
		}
	}

	func getSymbol(id: UUID, database: Database) -> EventLoopFuture<SymbolModel> {
		SymbolModel.query(on: database)
			.filter(\.$id == id)
			.first()
			.unwrap(or: Abort(.badRequest, reason: "Symbol with requested ID doesn't exist in database"))
	}

	func getSymbol(named name: String, database: Database) -> EventLoopFuture<SymbolModel?> {
		SymbolModel.query(on: database)
			.filter(\.$name == name)
			.first()
	}

	func loadSymbolContent(on symbol: EventLoopFuture<SymbolModel>, database: Database) -> EventLoopFuture<SymbolModel> {
		symbol.flatMap { symbolModel -> EventLoopFuture<SymbolModel> in
			symbolModel
				.$connections
				.load(on: database)
				.flatMap { _ -> EventLoopFuture<Void> in
					let tagLoads = symbolModel.connections.map { connection in
						connection.$tag.load(on: database)
					}
					return database.eventLoop.flatten(tagLoads)
				}
				.transform(to: symbolModel)
		}
	}

	// MARK: - Tags
	func createTag(withValue value: String, database: Database) -> EventLoopFuture<SymbolTag> {
		let existingTag = getTag(withValue: value, database: database)
		return existingTag.flatMap { optTag -> EventLoopFuture<SymbolTag> in
			guard optTag == nil else {
				return database.eventLoop.future(error: Abort(.badRequest, reason: "A Tag with that value already exists."))
			}
			let tag = SymbolTag(value: value)
			return tag.create(on: database)
				.transform(to: tag)
		}
	}

	/// Retrieves existing tag from database if it exists, creating it if it doesnt.
	func getCreateTag(named value: String, database: Database) -> EventLoopFuture<SymbolTag> {
		getTag(withValue: value, database: database)
			.flatMap { optTag -> EventLoopFuture<SymbolTag> in
				if let tag = optTag {
					return database.eventLoop.future(tag)
				} else {
					let tag = SymbolTag(value: value)
					return tag.create(on: database)
						.transform(to: tag)
				}
			}
	}

	func getTag(id: UUID, database: Database) -> EventLoopFuture<SymbolTag> {
		SymbolTag.query(on: database)
			.filter(\.$id == id)
			.first()
			.unwrap(or: Abort(.badRequest, reason: "Tag with requested ID doesn't exist in database"))
	}

	func getTag(withValue value: String, database: Database) -> EventLoopFuture<SymbolTag?> {
		SymbolTag.query(on: database)
			.filter(\.$value == value)
			.first()
	}

	// MARK: - Connections
	func createConnectionBetween(symbolID: UUID, andTagID tagID: UUID, createdByID: UUID, expiration: Date? = nil, on database: Database) -> EventLoopFuture<SymbolTagConnection> {
		let checkIfSymbolExists = getSymbol(id: symbolID, database: database)
		return checkIfSymbolExists.flatMap { _ -> EventLoopFuture<SymbolTagConnection> in
			return self.getTag(id: tagID, database: database).flatMap { _ -> EventLoopFuture<SymbolTagConnection> in
				let checkExisting = self.getConnectionBetween(symbolID: symbolID, andTagID: tagID, database: database)
				return checkExisting.flatMap { optConnection -> EventLoopFuture<SymbolTagConnection> in
					guard optConnection == nil else {
						return database.eventLoop.future(error: Abort(.badRequest, reason: "Connection already exists. Use existing connection."))
					}

					let connection = SymbolTagConnection(tagID: tagID, symbolID: symbolID, createdBy: createdByID, expiration: expiration)
					return connection.create(on: database)
						.transform(to: connection)
				}
			}
		}
	}

	func createConnectionBetween(symbol: EventLoopFuture<SymbolModel>, andTag tag: EventLoopFuture<SymbolTag>, createdBy creator: EventLoopFuture<UserModel>, expiration: Date? = nil, database: Database) -> EventLoopFuture<SymbolTagConnection> {
		creator.flatMap { creator in
			symbol.flatMap { symbolModel in
				tag.flatMap { tagModel in
					self.createConnectionBetween(symbolID: symbolModel.id!, andTagID: tagModel.id!, createdByID: creator.id!, expiration: expiration, on: database)
				}
			}
		}
	}

	func getConnectionBetween(symbolID: UUID, andTagID tagID: UUID, database: Database) -> EventLoopFuture<SymbolTagConnection?> {
		return SymbolTagConnection.query(on: database)
			.filter(\.$symbol.$id == symbolID)
			.filter(\.$tag.$id == tagID)
			.first()
	}

	func getConnectionBetween(symbol: EventLoopFuture<SymbolModel>, andTag tag: EventLoopFuture<SymbolTag>, database: Database) -> EventLoopFuture<SymbolTagConnection?> {
		return symbol.flatMap { symbolModel in
			return tag.flatMap { tagModel in
				return self.getConnectionBetween(symbolID: symbolModel.id!, andTagID: tagModel.id!, database: database)
			}
		}
	}

	// MARK: - Request Handling
	func connectTag(_ req: Request) throws -> EventLoopFuture<SymbolModel.GetContent> {
		let user = try req.auth.require(UserModel.self)

		let connectReference = try req.content.decode(SFTagSymbolRequest.self)

		guard connectReference.validate() else {
			throw Abort(.badRequest)
		}

		let symbol = getSymbol(id: connectReference.symbolID, database: req.db)

		let tag = getCreateTag(named: connectReference.tagValue, database: req.db)

		let userFuture = req.eventLoop.future(user)
		let connection = createConnectionBetween(symbol: symbol, andTag: tag, createdBy: userFuture, database: req.db)

		return connection.flatMap { _ -> EventLoopFuture<SymbolModel.GetContent> in
			self.loadSymbolContent(on: symbol, database: req.db)
				.map(\.getContent)
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
			var terms = terms
			guard let searchTerm = terms.popLast() else { return combined }
			let termCount = Double(searchTerm.count)

			let tagMatch = SymbolTag.query(on: req.db)
				.filter(\.$value ~~ searchTerm)
				.with(\.$connections) { connection in
					connection.with(\.$symbol)
				}
				.limit(256)
				.all()

			let accumulator = combined.flatMap { (combinedDict: SymbolScore) -> EventLoopFuture<SymbolScore> in
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

			return queryFirstTerm(in: terms, combined: accumulator)
		}

		let combinedStarter = req.eventLoop.future(SymbolScore())
		let scores = queryFirstTerm(in: terms, combined: combinedStarter)

		return scores.map { scores -> [SFSymbolResultObject] in
			var results: [SFSymbolResultObject] = []
			for (symbol, score) in scores {
				let result = SFSymbolResultObject(id: symbol.id!,
												  value: symbol.name,
												  availability: symbol.availability,
												  localizations: symbol.localizationOptions,
												  deprecatedNames: symbol.deprecatedNames,
												  resultScore: score)
				results.append(result)
			}
			return results.sorted { $0.resultScore > $1.resultScore }
		}
	}
}
