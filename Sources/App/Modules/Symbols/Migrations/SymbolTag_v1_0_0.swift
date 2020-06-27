import Vapor
import Fluent

struct Symbols_v1_0_0: Migration {

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			database.schema(SymbolTag.schema)
			.id()
			.field(SymbolTag.FieldKeys.value, .string, .required)
			.unique(on: SymbolTag.FieldKeys.value)
			.create(),

			database.schema(SymbolModel.schema)
			.id()
			.field(SymbolModel.FieldKeys.name, .string, .required)
			.field(SymbolModel.FieldKeys.restriction, .string)
			.field(SymbolModel.FieldKeys.availability, .int, .required)
			.unique(on: SymbolModel.FieldKeys.name)
			.create(),

			database.schema(SymbolTagConnection.schema)
			.id()
			.field(SymbolTagConnection.FieldKeys.score, .int, .required)
			.field(SymbolTagConnection.FieldKeys.expiration, .datetime)
			.field(SymbolTagConnection.FieldKeys.tagID, .uuid, .required)
			.foreignKey(SymbolTagConnection.FieldKeys.tagID, references: SymbolTag.schema, .id)
			.field(SymbolTagConnection.FieldKeys.symbolID, .uuid, .required)
			.foreignKey(SymbolTagConnection.FieldKeys.symbolID, references: SymbolModel.schema, .id)
			.field(SymbolTagConnection.FieldKeys.createdByID, .uuid, .required)
			.foreignKey(SymbolTagConnection.FieldKeys.createdByID, references: UserModel.schema, .id)
			.create()
		])
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			database.schema(SymbolTag.schema).delete(),
			database.schema(SymbolModel.schema).delete(),
			database.schema(SymbolTagConnection.schema).delete(),
		])
	}

}

