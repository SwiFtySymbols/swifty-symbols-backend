//: Playground - noun: a place where people can play

import Foundation

enum SFSymbolLocalizationOptions: String, Codable {
	case rightToLeft = "rtl"
	case arabic = "ar"
	case devanagari = "hi"
	case hebrew = "he"
}

struct SFSymbol: Codable {
	enum SFVersion: Int, Codable {
		case one = 1
		case two
	}

	var name: String
	let sfVersionAvailability: SFVersion
	var localizations: [SFSymbolLocalizationOptions] = []
	var deprecatedNames: [String] = []
}

let sfSymbolListFile = URL(fileURLWithPath: "/Applications/SF Symbols beta.app/Contents/Resources/name_availability.plist")
let deprecationListFile = URL(fileURLWithPath: "/Applications/SF Symbols beta.app/Contents/Resources/name_aliases_strings.txt")

let plistData = try Data(contentsOf: sfSymbolListFile)
let deprecationData = try Data(contentsOf: deprecationListFile)


//process deprecation data
let depTotal = String(data: deprecationData, encoding: .utf8)!
let depLines = depTotal.split(separator: "\n").map { String($0) }
// [newname: oldname]
let deprecatedNames = depLines.reduce(into: [String: [String]]()) {
	let parts = $1.split(separator: "=").map { String($0) }

	let cleaned: [String] = parts.map {
		let clean = $0.trimmingCharacters(in: CharacterSet(charactersIn: " \";"))
		return clean
	}

	$0[cleaned[1], default: []].append(cleaned[0])
}


//process symbol data
let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)

let symbolExtraction = (plist as? [String: Any])?["symbols"]

let versionMap = ["2019": SFSymbol.SFVersion.one, "2020": SFSymbol.SFVersion.two]

func getLocalization(from string: String) -> (base: String, localization: SFSymbolLocalizationOptions)? {
	guard let lastSub = string.split(separator: ".").last else {
		return nil
	}
	let localizationStr = String(lastSub)
	guard let localization = SFSymbolLocalizationOptions(rawValue: localizationStr) else { return nil }
	let index = string.lastIndex(of: ".") ?? string.endIndex
	return (String(string[..<index]), localization)
}

let symbolDictionary: [String: SFSymbol] = (symbolExtraction as? [String: String])?
	.reduce(into: [:], {
		let name = $1.key
		guard let version = versionMap[$1.value] else {
			fatalError("Invalid version year")
		}
		var key = name
		var newSymbol = SFSymbol(name: key, sfVersionAvailability: version)
		newSymbol.deprecatedNames = deprecatedNames[key] ?? []

		if let (base, localization) = getLocalization(from: name) {
			key = base
			newSymbol = $0?[key] ?? SFSymbol(name: key, sfVersionAvailability: version)
			newSymbol.localizations.append(localization)
			newSymbol.deprecatedNames = deprecatedNames[key] ?? []
			$0?[key] = newSymbol
		} else if $0?[key] == nil {
			$0?[key] = newSymbol
		}

	}) ?? [:]

let cleanSymbolDictionary = deprecatedNames.reduce(into: symbolDictionary) {
	for deprecatedName in $1.value {
		$0[deprecatedName] = nil
	}
}


let symbolList = cleanSymbolDictionary.map(\.value)


let jsonEncoder = JSONEncoder()
jsonEncoder.outputFormatting = [.sortedKeys]
let jsonData = try jsonEncoder.encode(symbolList)
let plistDataExport = try PropertyListEncoder().encode(symbolList)

print(String(data: jsonData, encoding: .utf8)!)
