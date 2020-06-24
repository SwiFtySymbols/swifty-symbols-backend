import Fluent
import Vapor

struct UserMigrationSeed: Migration {

	private func users() -> [UserModel] {
		let users: [(email: String, pass: String)] = [("he@ho.hum", "Aabc123!")]

		return users.compactMap {
			do {
				let hashedPassword = try Bcrypt.hash($0.pass)
				return UserModel(email: $0.email, password: hashedPassword)
			} catch {
				print("error hashing password: \(error)")
				return nil
			}
		}
	}

	func prepare(on database: Database) -> EventLoopFuture<Void> {
		users().create(on: database)
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		UserModel.query(on: database).delete()
	}
}
