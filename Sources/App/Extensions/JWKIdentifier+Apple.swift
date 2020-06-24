import Vapor
import JWT

extension JWKIdentifier {
	static let apple = Self(string: Environment.siwaJWKID)
}
