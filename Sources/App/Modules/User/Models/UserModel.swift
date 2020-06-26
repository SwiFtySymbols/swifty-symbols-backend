import Vapor
import Fluent
import JWT

final class UserModel: Model {

	static let schema = "user_users"

	enum FieldKeys {
		static var email: FieldKey { "email" }
		static var password: FieldKey { "password" }
		static var appleID: FieldKey { "appleid" }
	}

	@ID()
	var id: UUID?

	@Field(key: FieldKeys.email)
	var email: String

	@Field(key: FieldKeys.password)
	var password: String

	@Field(key: FieldKeys.appleID)
	var appleID: String?

	init() {}

	init(id: UserModel.IDValue? = nil, email: String, password: String, appleID: String? = nil) {
		self.id = id
		self.email = email.lowercased()
		self.password = password
		self.appleID = appleID
	}
}

extension UserModel: Authenticatable {}

//extension UserModel: SessionAuthenticatable {
//	typealias SessionID = UUID
//
//	var sessionID: SessionID { self.id! }
//}

extension UserModel {
	static func siwa(req: Request, idToken: String, appId: String) -> EventLoopFuture<UserModel> {
		req.jwt.apple.verify(idToken, applicationIdentifier: appId)
			.flatMap { identityToken -> EventLoopFuture<UserModel> in
				guard let email = identityToken.email else {
					return req.eventLoop.future(error: Abort(.unauthorized))
				}
				return UserModel.query(on: req.db)
					.group(.or) { $0
						.filter(\.$appleID == identityToken.subject.value)
						.filter(\.$email == email)
				}
			.first()
				.map { user -> UserModel in
					guard let user = user else {
						return UserModel(email: email,
										 password: UUID().uuidString,
										 appleID: identityToken.subject.value)
					}
					return user
				}
			}
			.flatMap { user in
				user.save(on: req.db).map { user }
			}
	}
}

extension UserModel {
	struct CreateContext: Content {
		let email: String
		let password: String
		let passwordVerify: String
	}
}
