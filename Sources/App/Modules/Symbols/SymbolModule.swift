import Vapor
import Fluent
import ViperKit

struct SymbolModule: ViperModule {
	static var name = "symbol"

	var router: ViperRouter? {
		SymbolRouter()
	}

	var migrations: [Migration] {
		[
			Symbols_v1_0_0(),
		]
	}

}
