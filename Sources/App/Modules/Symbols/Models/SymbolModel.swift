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
		static var deprecatedNames: FieldKey { "deprecatedNames" }
		static var localizationOptions: FieldKey { "localizationOptions" }
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

	@Field(key: FieldKeys.deprecatedNames)
	var deprecatedNames: [String]

	@Field(key: FieldKeys.localizationOptions)
	var localizationOptions: [SFSymbolLocalizationOptions]

	init() {}

	init(id: UUID = UUID(), name: String, restriction: String? = nil, availability: SFVersionAvailability, deprecatedNames: [String] = [], localizationOptions: [SFSymbolLocalizationOptions] = []) {
		self.id = id
		self.name = name
		self.restriction = restriction
		self.availability = availability
		self.deprecatedNames = deprecatedNames
		self.localizationOptions = localizationOptions
	}
}

extension SymbolModel: Hashable {
	static func == (lhs: SymbolModel, rhs: SymbolModel) -> Bool {
		lhs.id == rhs.id
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}

extension SymbolModel: ListContentRepresentable {
	var listContent: ListItem {
		.init(id: id!,
			  value: name,
			  localizations: localizationOptions,
			  deprecatedNames: deprecatedNames.isEmpty ? nil : deprecatedNames,
			  availability: availability)
	}

	typealias ListItem = SFSymbolListObject
}

extension SymbolModel: GetContentRepresentable {
	typealias GetContent = SFSymbolGetObject

	var getContent: SFSymbolGetObject {
		let tags = $connections.value?
			.map(\.$tag.value?.listContent)
			.compactMap({ $0 })

		return .init(id: id!,
			  value: name,
			  availability: availability,
			  localizations: localizationOptions,
			  deprecatedNames: deprecatedNames,
			  tags: tags ?? [])
	}
}

extension SFSymbolListObject: Content {}
extension SFSymbolGetObject: Content {}
extension SFSymbolResultObject: Content {}
