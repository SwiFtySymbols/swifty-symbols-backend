import Vapor
import Fluent
import SwiFtySymbolsShared

fileprivate class RefValue<T> {
	private let theQueue = DispatchQueue(label: "theQueue")
	private var _value: T
	var value: T {
		get { theQueue.sync { _value } }
		set { theQueue.sync { _value = newValue } }
	}

	init(value: T) {
		self._value = value
	}
}

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

		try seedDB(database) { progressValue in
			loadingBar.activity.currentProgress = progressValue
		} titleProgressUpdater: { newTitle in
			loadingBar.activity.title = newTitle
		}
	}

	func seedDB(_ database: Database, progressUpdater: ((Double) -> Void)? = nil, titleProgressUpdater: ((String) -> Void)? = nil) throws {
		let symbolSeeds = try seedLoader()
		// there are 5 distinct sections: symbol creation, tag creation, symbol fetching, tag fetching, connection creation
		let totalActions = Double(symbolSeeds.count * 5)
		let progressTracker = RefValue(value: Double(0))

		let user = UserModel.query(on: database)
			.filter(\.$email == UserModel.systemUsername)
			.first()
			.unwrap(or: Abort(.badRequest))

		func progressUpdate<T>(_ ignored: T) {
			progressTracker.value += 1 / totalActions
			progressUpdater?(progressTracker.value)
		}

		titleProgressUpdater?("Creating Symbols")
		let createSymbols = symbolSeeds.map { importSymbol -> EventLoopFuture<SymbolModel> in
			connectionController.createSymbol(named: importSymbol.name,
											  restriction: nil,
											  availability: importSymbol.sfVersionAvailability,
											  deprecatedNames: importSymbol.deprecatedNames,
											  localizationOptions: importSymbol.localizations,
											  database: database,
											  failGracefully: true)
				.always(progressUpdate)
		}

		let flattenSymbols = database.eventLoop.flatten(createSymbols)
		_ = try flattenSymbols.wait()

		titleProgressUpdater?("Creating Tags")
		let createTags = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTag]> in
			let depTags = importSymbol.deprecatedNames.map {
				connectionController.createTag(withValue: $0, database: database, failGracefully: true)
			}
			let baseTag = connectionController.createTag(withValue: importSymbol.name, database: database, failGracefully: true)

			let allTags = depTags + [baseTag]
			return database.eventLoop.flatten(allTags)
				.always(progressUpdate)
		}

		let flattenedTags = database.eventLoop.flatten(createTags)
		_ = try flattenedTags.wait()


		titleProgressUpdater?("Creating Connections")
		let createConnections = symbolSeeds.map { importSymbol -> EventLoopFuture<[SymbolTagConnection]> in
			let symbol = connectionController.getSymbol(named: importSymbol.name, database: database)
				.flatMap { optModel -> EventLoopFuture<SymbolModel> in
					guard let model = optModel else {
						return database.eventLoop.future(error: Abort(.badRequest, reason: "Requested symbol doesn't exist"))
					}
					return database.eventLoop.future(model)
						.always(progressUpdate)
				}

			let tagStrings = Set(importSymbol.deprecatedNames + [importSymbol.name])
			let tags = tagStrings.map { connectionController.getTag(withValue: $0, database: database) }
			let flattenedTags = database.eventLoop.flatten(tags).flatMap { optTags -> EventLoopFuture<[SymbolTag]> in
				database.eventLoop.future(optTags.compactMap { $0 })
					.always(progressUpdate)
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
						.always(progressUpdate)
				}
				return database.eventLoop.flatten(test)
			}
			return connections
		}

		let allConnections = database.eventLoop.flatten(createConnections)
		_ = try allConnections.wait()
	}
}
