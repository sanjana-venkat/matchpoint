// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MatchPointRating",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "MatchPointRating", targets: ["MatchPointRating"])
    ],
    targets: [
        .target(
            name: "MatchPointRating",
            path: "PickleMatch/Models",
            exclude: ["CommunityModels.swift", "EloRating.swift", "Models.swift"],
            sources: ["RatingEngine.swift"]
        ),
        .testTarget(
            name: "MatchPointRatingTests",
            dependencies: ["MatchPointRating"],
            path: "PickleMatchTests/Rating"
        )
    ]
)
