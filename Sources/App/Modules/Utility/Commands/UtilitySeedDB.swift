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

		let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
			.map { $0 + " Database seed in progress..." }

		let loadingBar = context.console.customActivity(frames: frames)
		loadingBar.start()

		let symbolSeeds = try! seedLoader()

		let user = UserModel.query(on: database)
			.filter(\.$email == UserModel.systemUsername)
			.first()
			.unwrap(or: Abort(.badRequest))

		let createSymbols = symbolSeeds.map { importSymbol -> EventLoopFuture<SymbolModel> in
			connectionController.createSymbol(named: importSymbol.name,
											  restriction: nil,
											  availability: importSymbol.sfVersionAvailability,
											  deprecatedNames: importSymbol.deprecatedNames,
											  localizationOptions: importSymbol.localizations,
											  database: database,
											  failGracefully: true)
		}

		let flattenSymbols = database.eventLoop.flatten(createSymbols)
		_ = try flattenSymbols.wait()

		let createTags = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTag]> in
			let depTags = importSymbol.deprecatedNames.map {
				connectionController.createTag(withValue: $0, database: database, failGracefully: true)
			}
			let baseTag = connectionController.createTag(withValue: importSymbol.name, database: database, failGracefully: true)

			let allTags = depTags + [baseTag]
			return database.eventLoop.flatten(allTags)
		}

		let flattenedTags = database.eventLoop.flatten(createTags)
		_ = try flattenedTags.wait()


		let createConnections = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTagConnection]> in
			let symbol = connectionController.getSymbol(named: importSymbol.name, database: database)
				.flatMap { optModel -> EventLoopFuture<SymbolModel> in
					guard let model = optModel else {
						return database.eventLoop.future(error: Abort(.badRequest, reason: "Requested symbol doesn't exist"))
					}
					return database.eventLoop.future(model)
				}

			let tagStrings = Set(importSymbol.deprecatedNames + [importSymbol.name])
			let tags = tagStrings.map { connectionController.getTag(withValue: $0, database: database) }
			let flattenedTags = database.eventLoop.flatten(tags).flatMap { optTags -> EventLoopFuture<[SymbolTag]> in
				database.eventLoop.future(optTags.compactMap { $0 })
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
				}
				return database.eventLoop.flatten(test)
			}
			return connections
		}

		let allConnections = database.eventLoop.flatten(createConnections)
		_ = try allConnections.wait()
	}
}
