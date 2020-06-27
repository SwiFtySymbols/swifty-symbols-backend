import Vapor
import Fluent
import ViperKit

final class SymbolTagConnection: ViperModel {
	typealias Module = SymbolModule

	static var name = "connection"

	enum FieldKeys {
		static var tagID: FieldKey { "tagID" }
		static var score: FieldKey { "score" }
		static var symbolID: FieldKey { "symbolID" }
		static var createdByID: FieldKey { "createdByID" }
//		static var recommendedBy: FieldKey { "recommendedBy" }
		static var expiration: FieldKey { "expiration" }
	}

	@ID()
	var id: UUID?

	@Parent(key: FieldKeys.tagID)
	var tag: SymbolTag

	@Field(key: FieldKeys.score)
	var score: Int

	@Parent(key: FieldKeys.symbolID)
	var symbol: SymbolModel

	@Parent(key: FieldKeys.createdByID)
	var createdBy: UserModel

//	@Parent(key: FieldKeys.recommendedBy)
//	var recommendedBy: Set<UserModel>

	@Field(key: FieldKeys.expiration)
	var expiration: Date?

	init() {}

	init(id: UUID? = nil, tagID: SymbolTag.IDValue, symbolID: SymbolModel.IDValue, createdBy: UserModel.IDValue, expiration: Date? = Date().addingTimeInterval(2_592_000)) {
		self.id = id
		self.score = 0
		self.$tag.id = tagID
		self.$symbol.id = symbolID
		self.$createdBy.id = createdBy
		self.expiration = expiration
	}

}
