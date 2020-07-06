import Vapor
import Fluent
import ViperKit

struct SymbolModule: ViperModule {
	static var name = "symbol"

	let seedLoader: () throws -> [SymbolProductionSeed_v1_0_0.SymbolSeedValue]

	var router: ViperRouter? {
		SymbolRouter()
	}

	var migrations: [Migration] {
		[
			Symbols_v1_0_0(),
			SymbolProductionSeed_v1_0_0(seedLoader: seedLoader),
		]
	}

}
