import Fluent
import FluentPostgresDriver
import Vapor
import ViperKit

// Called before your application initializes.
public func configure(_ app: Application) throws {
	// Serves files from `Public/` directory
	// app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	try app.databases.use(.postgres(url: Environment.databaseURL), as: .psql)

	// Configure SQLite database
//	app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

	// Configure migrations

	let modules: [ViperModule] = [
		UserModule(),
		SymbolModule(),
	]

	try app.viper.use(modules)

	try app.autoMigrate().wait()
}
