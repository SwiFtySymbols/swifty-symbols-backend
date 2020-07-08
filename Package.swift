// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "SwiFtySymbolsBE",
    platforms: [
		.macOS(.v10_15),
		.iOS(.v13),
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "4.5.0"),
		.package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc"),
		.package(url: "https://github.com/vapor/fluent-postgres-driver", from: "2.0.0-rc"),
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0-rc"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.0.0-rc"),

		.package(url: "https://github.com/binarybirds/content-api.git", from: "1.0.0"),
		.package(url: "https://github.com/binarybirds/viper-kit.git", from: "1.0.0"),
		.package(url: "https://github.com/binarybirds/spec.git", from: "1.0.0"),


		// use this when committing
		.package(url: "https://github.com/SwiFtySymbols/swifty-symbols-shared.git", .branch("master")),
		// use this if you need to modify shared resources locally, then remember to communicate to the rest of the team and push
//		.package(name: "swifty-symbols-shared", path: "../SwiFtySymbolsShared"),
	],
	targets: [
		.target(
			name: "App",
			dependencies: [
				.product(name: "Vapor", package: "vapor"),
				.product(name: "Fluent", package: "fluent"),
				.product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
				.product(name: "JWT", package: "jwt"),

				.product(name: "ContentApi", package: "content-api"),
				.product(name: "ViperKit", package: "viper-kit"),
				.product(name: "SwiFtySymbolsShared", package: "swifty-symbols-shared"),
			] ,
			swiftSettings: [
				// Enable better optimizations when building in Release configuration. Despite the use of
				// the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
				// builds. See <https://github.com/swift-server/guides#building-for-production> for details.
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
			]
		),
		.target(name: "Run", dependencies: [
			.target(name: "App"),
		]),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "Spec", package: "spec"),
			.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
		])
	]
)

