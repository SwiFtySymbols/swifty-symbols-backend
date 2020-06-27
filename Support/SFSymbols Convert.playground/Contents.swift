//: Playground - noun: a place where people can play

import Foundation

struct SFSymbol: Codable {
	enum SFVersion: Int, Codable {
		case one = 1
		case two
	}

	let name: String
	let sfVersionAvailability: SFVersion
}

let sfSymbolListFile = URL(fileURLWithPath: "/Applications/SF Symbols beta.app/Contents/Resources/name_availability.plist")

let plistData = try Data(contentsOf: sfSymbolListFile)

let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)

let symbolExtraction = (plist as? [String: Any])?["symbols"]

let versionMap = ["2019": SFSymbol.SFVersion.one, "2020": SFSymbol.SFVersion.two]

let symbolList: [SFSymbol] = (symbolExtraction as? [String: String])?
	.reduce(into: [], {
		let name = $1.key
		guard let version = versionMap[$1.value] else {
			fatalError("Invalid version year")
		}
		$0?.append(SFSymbol(name: name, sfVersionAvailability: version))
	}) ?? []


let jsonEncoder = JSONEncoder()
jsonEncoder.outputFormatting = [.sortedKeys]
let jsonData = try jsonEncoder.encode(symbolList)
let plistDataExport = try PropertyListEncoder().encode(symbolList)

print(String(data: jsonData, encoding: .utf8)!)
