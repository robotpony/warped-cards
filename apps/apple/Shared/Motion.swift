// Animation tools for diagnosing motion: a global slow-motion scale and a frame meter.
import AppKit
import os
import QuartzCore

/// Every animation duration and pause goes through here, so slow motion can stretch them all.
enum Motion {
    /// 1 is normal; 5 plays everything five times slower.
    nonisolated(unsafe) static var scale = 1.0
    static func t(_ seconds: Double) -> Double { seconds * scale }
    static func ms(_ milliseconds: Double) -> Int { Int(milliseconds * scale) }
}

/// Counts frames and hitches (a frame that took over 1.5 times the display's frame time),
/// shown in the side panel and logged (subsystem ca.robotpony.cribmaze, category frames).
@MainActor @Observable
final class FrameMeter: NSObject {
    @ObservationIgnored private(set) var fps = 0.0
    private(set) var hitches = 0
    private(set) var worstMs = 0.0
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var windowStart: CFTimeInterval = 0
    @ObservationIgnored private let log = Logger(subsystem: "ca.robotpony.cribmaze", category: "frames")
    /// Only count hitches while something is moving.
    @ObservationIgnored var moving: () -> Bool = { false }

    func start(on view: NSView) {
        guard link == nil else { return }
        let l = view.displayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func reset() { hitches = 0; worstMs = 0 }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let expected = l.targetTimestamp - l.timestamp
        if last > 0, moving() {
            let dt = now - last
            if expected > 0, dt > expected * 1.5 {
                hitches += 1
                worstMs = max(worstMs, dt * 1000)
                log.notice("hitch \(Int(dt * 1000)) ms (frame \(Int(expected * 1000)) ms)")
            }
        }
        last = now
        frames += 1
        if now - windowStart >= 0.5 {
            if windowStart > 0 { fps = Double(frames) / (now - windowStart) }
            frames = 0; windowStart = now
        }
    }
}

/// Starts the meter on the window's content view.
import SwiftUI
struct FrameMeterHost: NSViewRepresentable {
    let meter: FrameMeter
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { meter.start(on: v) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
