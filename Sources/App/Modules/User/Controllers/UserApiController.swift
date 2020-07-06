import Vapor
import Fluent

struct UserApiController {

	func signUp(req: Request) throws -> EventLoopFuture<Response> {
		let user = try req.content.decode(UserModel.CreateContext.self)

		guard user.password == user.passwordVerify else {
			throw Abort(.badRequest, reason: "Passwords didn't match! C'mon. You should be checking this on the client side ffs.")
		}

		let hashedPassword = try Bcrypt.hash(user.password)
		let userModel = UserModel(email: user.email, password: hashedPassword)

		return userModel.create(on: req.db)
			.flatMap { _ in
				req.eventLoop.future(Response(status: .created))
			}
	}

	func login(req: Request) throws -> EventLoopFuture<UserTokenModel.GetContent> {
		guard let user = req.auth.get(UserModel.self) else {
			throw Abort(.unauthorized)
		}
		return UserTokenModel.create(on: req.db, for: user.id!)
			.map { $0.getContent }
	}

	func signInWithApple(req: Request) throws -> EventLoopFuture<UserTokenModel.GetContent> {
		struct AuthRequest: Content {
			enum CodingKeys: String, CodingKey {
				case idToken = "id_token"
			}
			let idToken: String
		}
		let auth = try req.content.decode(AuthRequest.self)

		return UserModel.siwa(req: req, idToken: auth.idToken, appId: Environment.siwaAppID)
			.flatMap { user in
				UserTokenModel.create(on: req.db, for: user.id!)
					.map { $0.getContent }
		}
	}
}
