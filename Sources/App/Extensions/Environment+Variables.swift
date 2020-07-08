import Vapor

extension Environment {

	static let databaseURL: URL? = {
		guard let urlString = get("DATABASE_URL") else { return nil }
		return URL(string: urlString)
	}()

	static let siwaID = get("SIWA_ID") ?? "SIWA_ID"
	static let siwaAppID = get("SIWA_APP_ID") ?? "SIWA_APP_ID"
	static let siwaRedirectURL = get("SIWA_REDIRECT_URL") ?? "SIWA_REDIRECT_URL"
	static let siwaTeamID = get("SIWA_TEAM_ID") ?? "SIWA_TEAM_ID"
	static let siwaJWKID = get("SIWA_JWK_ID") ?? "SIWA_JWK_ID"
	static let siwaKey: String = {
		let envVar = get("SIWA_KEY")
		return envVar?.base64Decoded ?? "SIWA_KEY"
	}()

	static let superAdminUser: String = {
		guard let value = get("SUPER_ADMIN_USER") else {
			print("Warning: ENV DIDN'T PROVIDE A SUPER ADMIN USERNAME. `root` used for super admin user!")
			return "root"
		}
		return value
	}()

	static let superAdminPassword: String = {
		guard let value = get("SUPER_ADMIN_PASSWORD") else {
			let fallback = [UInt8].random(count: 24).base64
			print("Warning: ENV DIDN'T PROVIDE A SUPER ADMIN PASSWORD. `\(fallback)` (no backticks) used for super admin password!")
			return fallback
		}
		return value
	}()

}
