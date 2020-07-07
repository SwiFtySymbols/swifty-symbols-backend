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

	/// Remember to store all lowercase values
	@Field(key: FieldKeys.value)
	var value: String

	@Children(for: \.$tag)
	var connections: [SymbolTagConnection]

	@Siblings(through: SymbolTagConnection.self, from: \.$tag, to: \.$symbol)
	var symbols: [SymbolModel]

	init() {}

	init(id: UUID = UUID(), value: String) {
		self.id = id
		self.value = value.lowercased()
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
		let symbols = $symbols.value?
			.map(\.listContent)
		
		if symbols == nil {
			print("Attempted fetching SymbolTag sibling without loading first.")
		}

		return .init(id: id!, value: value, symbols: symbols ?? [])
	}
}

extension SFSymbolTagListObject: Content {}
extension SFSymbolTagGetObject: Content {}

extension SFTagSymbolRequest: Content {
	/// Returns true when valid
	func validate() -> Bool {
		tagValue == tagValue.lowercased() &&
			!tagValue.contains(" ")
	}
}
