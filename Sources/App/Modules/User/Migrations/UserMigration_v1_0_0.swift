import Vapor
import Fluent

struct UserMigration_v1_0_0: Migration {

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			database.schema(UserModel.schema)
				.id()
				.field(UserModel.FieldKeys.email, .string, .required)
				.field(UserModel.FieldKeys.password, .string, .required)
				.field(UserModel.FieldKeys.appleID, .string)
				.unique(on: UserModel.FieldKeys.email)
				.unique(on: UserModel.FieldKeys.appleID)
				.create(),

			database.schema(UserTokenModel.schema)
			.id()
				.field(UserTokenModel.FieldKeys.value, .string, .required)
				.field(UserTokenModel.FieldKeys.userId, .uuid, .required)
				.foreignKey(UserTokenModel.FieldKeys.userId, references: UserModel.schema, .id)
				.unique(on: UserTokenModel.FieldKeys.value)
				.create()
		])
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.eventLoop.flatten([
			database.schema(UserModel.schema).delete(),
			database.schema(UserTokenModel.schema).delete()
		])
	}

}

