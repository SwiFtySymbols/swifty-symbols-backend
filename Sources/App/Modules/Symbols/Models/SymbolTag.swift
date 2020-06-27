import Fluent
import Vapor
import ViperKit

final class SymbolTag: ViperModel {


//	static let sc
	typealias Module = SymbolModule

	static var name = "symbol_tags"

	enum FieldKeys {
		static var value: FieldKey { "value" }
	}

	@ID()
	var id: UUID?

	@Field(key: FieldKeys.value)
	var value: String

	@Children(for: \.$tag)
	var connections: [SymbolTagConnection]


	init() {}

	init(id: UUID? = nil, value: String) {
		self.id = id
		self.value = value
	}
}
