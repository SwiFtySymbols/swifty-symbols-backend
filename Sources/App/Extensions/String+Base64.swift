import Foundation

extension String {
	var base64Encoded: String? {
		data(using: .utf8)?.base64EncodedString()
	}

	var base64Decoded: String? {
		guard let data = Data(base64Encoded: self) else { return nil }
		return String(data: data, encoding: .utf8)
	}
}

extension String {
	var bytes: [UInt8] {
		.init(utf8)
	}
}
