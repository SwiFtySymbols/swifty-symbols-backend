import Vapor


struct UtilityCommandGroup: CommandGroup {
	let commands: [String: AnyCommand]
	let help: String

	var defaultCommand: AnyCommand? {
		self.commands[UtilitySeedDatabase.name]
	}

	init(seedLoader: @escaping () throws -> [UtilitySeedDatabase.SymbolSeedValue]) {
		help = "Various utility tools"

		commands = [UtilitySeedDatabase.name: UtilitySeedDatabase(seedLoader: seedLoader)]
	}
}
