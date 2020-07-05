import Vapor
import Fluent
import ViperKit

struct SymbolTestSeed_v1_0_0: Migration {

	let testSymbol = SymbolModel(name: "test.name", availability: .one)

	let testTag = SymbolTag(value: "testtag")


	func prepare(on database: Database) -> EventLoopFuture<Void> {
		let testSymbol = SymbolModel(name: "test.name", availability: .one)
		let testTag = SymbolTag(value: "testtag")

		return testSymbol.create(on: database)
			.flatMap {
				testTag.create(on: database)
					.flatMap { _ in
						let user = UserModel.query(on: database)
							.first()
						return user.flatMap {
							guard let userModel = $0 else { return database.eventLoop.future() }
							let connection = SymbolTagConnection(tagID: testTag.id!, symbolID: testSymbol.id!, createdBy: userModel.id!)
							return connection.create(on: database)
						}
					}
			}
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			SymbolTagConnection.query(on: database).delete(),
			SymbolModel.query(on: database).delete(),
			SymbolTag.query(on: database).delete()
		])
	}

}

