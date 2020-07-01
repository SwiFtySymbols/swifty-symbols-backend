import Vapor
import Fluent
import ViperKit
import ContentApi
import SwiFtySymbolsShared

final class SymbolModel: ViperModel {
	typealias Module = SymbolModule

	static var name = "symbols"

	enum FieldKeys {
		static var name: FieldKey { "name" }
		static var restriction: FieldKey { "restriction" }
		static var availability: FieldKey { "availability" }
	}

	@ID()
	var id: UUID?

	@Children(for: \.$symbol)
	var connections: [SymbolTagConnection]

	@Field(key: FieldKeys.name)
	var name: String

	@Field(key: FieldKeys.restriction)
	var restriction: String?

	@Field(key: FieldKeys.availability)
	var availability: SFVersionAvailability

	init() {}

	init(id: UUID = UUID(), name: String, restriction: String? = nil, availability: SFVersionAvailability) {
		self.id = id
		self.name = name
		self.restriction = restriction
		self.availability = availability
	}
}

extension SymbolModel: ListContentRepresentable {
	var listContent: ListItem {
		.init(id: id!, value: name, availability: availability)
	}

	typealias ListItem = SFSymbolListObject
}

extension SymbolModel: GetContentRepresentable {
	typealias GetContent = SFSymbolGetObject

	var getContent: SFSymbolGetObject {
		.init(id: id!, value: name, availability: availability)
	}
}

extension SFSymbolListObject: Content {}
extension SFSymbolGetObject: Content {}
