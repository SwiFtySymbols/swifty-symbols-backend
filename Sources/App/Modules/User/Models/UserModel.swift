import Vapor
import Fluent
import ViperKit
import SwiFtySymbolsShared

final class UserModel: ViperModel {
	static let systemUsername = "system"
	static let superAdminUser = Environment.superAdminUser

	typealias Module = UserModule

	static let name = "users"

	enum FieldKeys {
		static var email: FieldKey { "email" }
		static var password: FieldKey { "password" }
		static var appleID: FieldKey { "appleid" }
		static var isAdmin: FieldKey { "isAdmin" }
	}

	@ID()
	var id: UUID?

	@Field(key: FieldKeys.email)
	var email: String

	@Field(key: FieldKeys.password)
	var password: String

	@Field(key: FieldKeys.appleID)
	var appleID: String?

	@Field(key: FieldKeys.isAdmin)
	var isAdmin: Bool

	init() {}

	init(id: UserModel.IDValue? = nil, email: String, password: String, appleID: String? = nil) {
		self.id = id
		self.email = email.lowercased()
		self.password = password
		self.appleID = appleID
		self.isAdmin = false
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
	typealias CreateContext = UserCreateContext
}

extension UserCreateContext: Content {}
