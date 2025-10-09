// swift-tools-version: 5.6
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "My App",
    platforms: [
        .iOS("15.2")
    ],
    products: [
        .iOSApplication(
            name: "My App",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.MyApp",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .game),
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)