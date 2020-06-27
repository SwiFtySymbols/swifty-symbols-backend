import Vapor
import Fluent
import ViperKit

final class SymbolModel: ViperModel {
	typealias Module = SymbolModule

	static var name = "symbols"

	enum FieldKeys {
		static var name: FieldKey { "name" }
		static var restriction: FieldKey { "restriction" }
		static var availability: FieldKey { "availability" }
	}

	enum SFVersionAvailability: Int, Codable {
		case one = 1
		case two
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

	init(id: UUID? = nil, name: String, restriction: String? = nil, availability: SFVersionAvailability) {
		self.id = id
		self.name = name
		self.restriction = restriction
		self.availability = availability
	}

}
