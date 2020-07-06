import Fluent
import Vapor

struct UserMigrationSeed: Migration {

	private func users() -> [UserModel] {
		let passwords = [
			UserModel.systemUsername: [UInt8].random(count: 64).base64,
			UserModel.superAdminUser: Environment.superAdminPassword
		]

		let hashedPasswords = passwords.reduce(into: [String: String]()) {
			do {
				let hashedPassword = try Bcrypt.hash($1.value)
				$0[$1.key] = hashedPassword
			} catch {
				print("error hashing password: \(error)")
			}
		}

		let systemUser = UserModel(
			email: UserModel.systemUsername,
			password: hashedPasswords[UserModel.systemUsername]!
		)

		let adminUser = UserModel(
			email: UserModel.superAdminUser,
			password: hashedPasswords[UserModel.superAdminUser]!
		)
		adminUser.isAdmin = true

		return [systemUser, adminUser]
	}

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		users().create(on: database)
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		UserModel.query(on: database).delete()
	}
}
