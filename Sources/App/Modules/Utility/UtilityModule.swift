import Vapor
import Fluent
import ViperKit

struct UtilityModule: ViperModule {
	static var name = "utility"

	let seedLoader: () throws -> [UtilitySeedDatabase.SymbolSeedValue]

	var commandGroup: CommandGroup? { UtilityCommandGroup(seedLoader: seedLoader) }
}
