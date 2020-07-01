import Fluent
import Vapor
import ViperKit
import ContentApi
import SwiFtySymbolsShared

final class SymbolTag: ViperModel {
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

	init(id: UUID = UUID(), value: String) {
		self.id = id
		self.value = value
	}
}

extension SymbolTag: ListContentRepresentable {
	typealias ListItem = SFSymbolTagListObject

	var listContent: SFSymbolTagListObject {
		.init(id: id!, value: value)
	}
}

extension SymbolTag: GetContentRepresentable {
	typealias GetContent = SFSymbolTagGetObject

	var getContent: SFSymbolTagGetObject {
		let symbols = connections
			.map(\.symbol)
			.map(\.listContent)
		return .init(id: id!, value: value, symbols: symbols)
	}
}

extension SFSymbolTagListObject: Content {}
extension SFSymbolTagGetObject: Content {}
