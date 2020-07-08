import Vapor
import Fluent
import SwiFtySymbolsShared

final class UtilitySeedDatabase: Command {

	static let name = "seed-db"

	struct Signature: CommandSignature {}

	let help = "Seeds database with SF Symbols with their starting tags and connections."

	struct SymbolSeedValue: Codable {
		let name: String
		let sfVersionAvailability: SFVersionAvailability
		let localizations: [SFSymbolLocalizationOptions]
		let deprecatedNames: [String]
	}

	let seedLoader: () throws -> [SymbolSeedValue]

	let connectionController = SymbolConnectionController()

	init(seedLoader: @escaping () throws -> [UtilitySeedDatabase.SymbolSeedValue]) {
		self.seedLoader = seedLoader
	}

	func run(using context: CommandContext, signature: Signature) throws {
		let app = context.application
		let database = app.db

		let loadingBar = context.console.progressBar(title: "Progress")
		loadingBar.start()

		let symbolSeeds = try seedLoader()
		// there are 5 distinct sections: symbol creation, tag creation, symbol fetching, tag fetching, connection creation
		let totalActions = Double(symbolSeeds.count * 5)

		func updateProgress<T>(_ ignored: T) {
			loadingBar.activity.currentProgress += 1 / totalActions
		}

		let user = UserModel.query(on: database)
			.filter(\.$email == UserModel.systemUsername)
			.first()
			.unwrap(or: Abort(.badRequest))

		loadingBar.activity.title = "Creating Symbols"
		let createSymbols = symbolSeeds.map { importSymbol -> EventLoopFuture<SymbolModel> in
			connectionController.createSymbol(named: importSymbol.name,
											  restriction: nil,
											  availability: importSymbol.sfVersionAvailability,
											  deprecatedNames: importSymbol.deprecatedNames,
											  localizationOptions: importSymbol.localizations,
											  database: database,
											  failGracefully: true)
				.always(updateProgress)
		}

		let flattenSymbols = database.eventLoop.flatten(createSymbols)
		_ = try flattenSymbols.wait()

		loadingBar.activity.title = "Creating Tags"
		let createTags = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTag]> in
			let depTags = importSymbol.deprecatedNames.map {
				connectionController.createTag(withValue: $0, database: database, failGracefully: true)
			}
			let baseTag = connectionController.createTag(withValue: importSymbol.name, database: database, failGracefully: true)

			let allTags = depTags + [baseTag]
			return database.eventLoop.flatten(allTags)
				.always(updateProgress)
		}

		let flattenedTags = database.eventLoop.flatten(createTags)
		_ = try flattenedTags.wait()


		loadingBar.activity.title = "Creating Connections"
		let createConnections = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTagConnection]> in
			let symbol = connectionController.getSymbol(named: importSymbol.name, database: database)
				.flatMap { optModel -> EventLoopFuture<SymbolModel> in
					guard let model = optModel else {
						return database.eventLoop.future(error: Abort(.badRequest, reason: "Requested symbol doesn't exist"))
					}
					return database.eventLoop.future(model)
						.always(updateProgress)
				}

			let tagStrings = Set(importSymbol.deprecatedNames + [importSymbol.name])
			let tags = tagStrings.map { connectionController.getTag(withValue: $0, database: database) }
			let flattenedTags = database.eventLoop.flatten(tags).flatMap { optTags -> EventLoopFuture<[SymbolTag]> in
				database.eventLoop.future(optTags.compactMap { $0 })
					.always(updateProgress)
			}

			let connections = flattenedTags.flatMap { (tags: [SymbolTag]) -> EventLoopFuture<[SymbolTagConnection]> in
				let test = tags.map { tag -> EventLoopFuture<SymbolTagConnection> in
					let tagFuture = database.eventLoop.future(tag)
					return self.connectionController.createConnectionBetween(symbol: symbol,
																			 andTag: tagFuture,
																			 createdBy: user,
																			 expiration: nil,
																			 database: database,
																			 failGracefully: true)
						.always(updateProgress)
				}
				return database.eventLoop.flatten(test)
			}
			return connections
		}

		let allConnections = database.eventLoop.flatten(createConnections)
		_ = try allConnections.wait()
	}
}
