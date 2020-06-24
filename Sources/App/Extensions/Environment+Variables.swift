import Vapor

extension Environment {

	static let databaseURL: String = {
		guard let value = get("DATABASE_URL") else {
			print("Warning: No database URL set, using 'DATABASE_URL'")
			return "DATABASE_URL"
		}
		return value
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

}
