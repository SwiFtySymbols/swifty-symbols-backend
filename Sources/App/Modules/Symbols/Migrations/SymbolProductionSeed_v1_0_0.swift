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

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		let symbolSeeds = try! seedLoader()

		let user = UserModel.query(on: database)
			.first()
			.unwrap(or: Abort(.badRequest))

		let futures: [EventLoopFuture<Void>] = symbolSeeds.map { importSymbol in
			let newSymbol = SymbolModel(name: importSymbol.name,
										availability: importSymbol.sfVersionAvailability,
										deprecatedNames: importSymbol.deprecatedNames,
										localizationOptions: importSymbol.localizations)
			let newTag = SymbolTag(value: importSymbol.name)

			return newSymbol.create(on: database).flatMap { _ in
				newTag.create(on: database).flatMap { _ in
					user.flatMap {
						let connection = SymbolTagConnection(tagID: newTag.id!, symbolID: newSymbol.id!, createdBy: $0.id!, expiration: nil)
						return connection.create(on: database)
					}
				}
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

