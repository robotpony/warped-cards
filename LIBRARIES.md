# Libraries and tools

Status: agreed, 2026-11-14. What the Swift app is built with, and why. The design is in [ARCHITECTURE.md](ARCHITECTURE.md).

The rule: Apple's own frameworks first, no third-party packages by default. A new library or tool MUST get a row here, with its reason, before it's added to the project.

## Tools

| Tool | Version | Use | Why |
|---|---|---|---|
| Xcode | 27 | Build, debug, Instruments, signing | The standard; installed |
| Swift | 6.4, Swift 6 language mode | Everything | Strict concurrency catches threading bugs at compile time |
| Swift Package Manager | With Swift | Engine, GameRecord, GameFX, stats and the CLI as one local package | Builds and tests without Xcode; `swift test` runs in a terminal |
| notarytool, stapler | With Xcode | Notarize and staple the Developer ID build (`apps/apple/scripts/release.sh`) | Required for a downloaded Mac app to open without warnings |
| GitHub CLI (`gh`) | Homebrew | Post release builds and notes to GitHub releases | The repo is on GitHub; already signed in |
| XcodeGen | Homebrew | Generates the app project from `project.yml` | Same as Scorekeep; no hand-merged `.xcodeproj` |
| swift-format | Bundled with the toolchain (`swift format`) | Formatting and lint | No extra install; one style for the repo |
| Swift Testing | With Swift | Unit, fixture and replay tests | Apple's current test framework; parameterized tests suit fixture files (Scorekeep still uses XCTest) |
| Instruments | With Xcode | Frame rate, audio glitches, bot search time | Effects need a frame budget, not a guess |
| Node | Existing | The JS mocks' tests, reading the shared fixtures | Already in use (`node --test`) |
| swiftly | Latest, from swift.org | Installs the Swift toolchain on Linux (`@linux`) | swift.org's own installer; installs per user and pins the same Swift as the Mac, so the engine builds with one compiler everywhere |
| Saira Semi Condensed | 4 weights, Google Fonts, OFL 1.1 | The UI typeface for every build, from `design/fonts/` | Decided 2026-11-16 so the Mac and Linux builds look the same; open licence, so any build can ship it |
| Godot | 4.7.2 | The Linux client (`apps/linux/`, `@linux`): scenes, shaders, particles, audio buses, input | Decided 2026-11-16 after a trial build. Open source, ships Linux ARM64 and Windows; the effects ui.md needs are built in |
| SwiftGodot | 0.99.2 | Loads the Swift engine into Godot as an extension (`@linux`) | One engine for every platform, so no second copy of the rules; very active; works on Linux ARM64 with Swift 6.4.2 |

Settings carried over from Scorekeep: warnings fail the build, and the build number is the git commit count.

## Apple frameworks

| Framework | Used by | For |
|---|---|---|
| Foundation | All | Codable, JSON, files, dates |
| SwiftUI | App | Scenes, menus, beta tools, most animation |
| Observation | App | `@Observable` GameSession |
| Metal (shader functions) | GameFX | Glows, shimmers and distortions through SwiftUI's shader effects |
| AVFAudio (AVAudioEngine) | GameFX | Low-latency sound effects, buses and mixing |
| Core Haptics | GameFX, iOS | Haptic patterns from AHAP files |
| AppKit (`NSHapticFeedbackManager`) | GameFX, Mac adapter | Trackpad feedback; kept to the adapter |
| Swift Charts | Beta tools | Stats dashboard graphs |
| UniformTypeIdentifiers | Beta tools | Exporting and importing records |
| SpriteKit | GameFX, only if needed | Particle emitters, if Canvas particles fall short |

## Apple packages allowed when needed

These are Apple's own open-source packages. Using one still needs a note here saying where and why.

| Package | Likely use |
|---|---|
| swift-collections | Ordered sets and deques, if the engine needs ordered containers |
| swift-algorithms | Combinations and permutations for counting and bot search |
| swift-argument-parser | Subcommands and flags for `cribmaze-sim` |

## Not used, and why

| What | Why not |
|---|---|
| Third-party game engines (Unity, Godot) | Swift and Apple frameworks are the agreed stack; the engine must stay plain Swift |
| SpriteKit or RealityKit for the whole board | Cards are flat, laid out and accessible; SwiftUI handles that better. SpriteKit stays an option for particles only |
| GameplayKit random sources | We need our own named, recorded streams and a scripted mode for replay |
| SwiftData or Core Data | Records are append-only files, and JSON Lines keeps them readable in the repo and by scripts |
| Analytics and crash SDKs | No tracking in release builds; beta records stay on the machine |
| Python | The Swift engine and `cribmaze-sim` replace the planned Python engine, so there's one rules implementation |
| ScorekeepCore's cribbage counting | Classic counting is written fresh for this game's needs (sets on a grid, combos per card, left-over cards); Scorekeep's code MAY be read for ideas, and we'll compare as we learn more |
