// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoiceAgent",
            targets: ["VoiceAgent"]
        )
    ],
    dependencies: [
        // AI Provider Dependencies
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.5.0"),
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.0"),
        
        // Networking and JSON
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.0"),
        
        // Audio Processing
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        
        // UI Components
        .package(url: "https://github.com/SwiftUIX/SwiftUIX", from: "0.1.9"),
        
        // Async/Await utilities
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceAgent",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
                .product(name: "OpenAI", package: "OpenAI"),
                "Alamofire",
                "SwiftyJSON",
                "AudioKit",
                "SwiftUIX",
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras")
            ],
            path: "Sources/VoiceAgent",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VoiceAgentTests",
            dependencies: ["VoiceAgent"],
            path: "Tests"
        )
    ]
)