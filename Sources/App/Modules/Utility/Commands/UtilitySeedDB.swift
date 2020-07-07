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

		let allFutures = database.eventLoop.flatten(futures)

		try allFutures.wait()
	}
}
