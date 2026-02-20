import ProjectDescription

let project = Project(
    name: "SimTag",
    organizationName: "com.simtag",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: false,
        disableSynthesizedResourceAccessors: false
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "",
            "CODE_SIGN_STYLE": "Automatic",
            "MACOSX_DEPLOYMENT_TARGET": "13.0",
            "SWIFT_VERSION": "5.9",
            "ENABLE_HARDENED_RUNTIME": "YES",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "SimTag",
            destinations: .macOS,
            product: .app,
            bundleId: "com.simtag.SimTag",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "SimTag",
                    "CFBundleShortVersionString": "1.0.0",
                    "CFBundleVersion": "1",
                    "LSUIElement": true, // Hide from Dock (menu bar only)
                    "NSSupportsAutomaticTermination": false,
                    "LSMinimumSystemVersion": "13.0",
                    "NSScreenCaptureDescription": "SimTag needs screen recording permission to detect iOS Simulator windows. This is used only to track window positions—not to record anything.",
                ]
            ),
            sources: ["SimTag/**"],
            resources: ["SimTag/Resources/**"],
            entitlements: .file(path: "SimTag/SimTag.entitlements"),
            dependencies: [],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "SWIFT_UPCOMING_FEATURE_FLAGS": "ExistentialAny ConciseMagicFile",
                ]
            )
        ),
        .target(
            name: "SimTagTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.simtag.SimTagTests",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["SimTagTests/**"],
            dependencies: [
                .target(name: "SimTag")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "SimTag",
            shared: true,
            buildAction: .buildAction(targets: ["SimTag"]),
            testAction: .targets(["SimTagTests"]),
            runAction: .runAction(executable: "SimTag"),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(executable: "SimTag"),
            analyzeAction: .analyzeAction(configuration: .debug)
        )
    ]
)
