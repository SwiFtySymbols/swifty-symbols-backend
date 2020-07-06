import Vapor
import Fluent
import ViperKit
import SwiFtySymbolsShared


struct SymbolProductionSeed_v1_0_0: Migration {
	struct SymbolSeedValue: Codable {
		let name: String
		let sfVersionAvailability: SFVersionAvailability
		let localizations: [SFSymbolLocalizationOptions]
		let deprecatedNames: [String]
	}

	let seedLoader: () throws -> [SymbolSeedValue]

	let connectionController = SymbolConnectionController()

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		let symbolSeeds = try! seedLoader()

		let user = UserModel.query(on: database)
			.filter(\.$email == UserModel.systemUsername)
			.first()
			.unwrap(or: Abort(.badRequest))

		let futures: [EventLoopFuture<Void>] = symbolSeeds.map { importSymbol in
			let symbol = connectionController.createSymbol(named: importSymbol.name,
														   restriction: nil,
														   availability: importSymbol.sfVersionAvailability,
														   deprecatedNames: importSymbol.deprecatedNames,
														   localizationOptions: importSymbol.localizations,
														   database: database)

			let depTags = importSymbol.deprecatedNames.map {
				connectionController.createTag(withValue: $0, database: database)
			}
			let baseTag = connectionController.createTag(withValue: importSymbol.name, database: database)

			let allTags = depTags + [baseTag]

			let connFutures = allTags.map { connectionController.createConnectionBetween(symbol: symbol, andTag: $0, createdBy: user, database: database) }

			let flat = database.eventLoop.flatten(connFutures)

			return flat.flatMapAlways { _ -> EventLoopFuture<Void> in
				return database.eventLoop.future()
			}
		}

		return database.eventLoop.flatten(futures)
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			SymbolTagConnection.query(on: database).delete(),
			SymbolModel.query(on: database).delete(),
			SymbolTag.query(on: database).delete()
		])
	}

}

