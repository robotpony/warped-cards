// The release app records nothing (ARCHITECTURE.md › Decisions, 2026-11-14).
@MainActor enum Recording { static func recorder() -> (any GameRecorder)? { nil } }
