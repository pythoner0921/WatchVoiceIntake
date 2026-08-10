import Foundation
import AVFoundation

// Records to temp .m4a segment files. Deliberately close to VivaDicta's
// WatchAudioRecorder.swift (see the feasibility report's D section) —
// AVAudioRecorder, not AVAudioEngine, is the simpler right tool for
// "record until stopped, hand back a file."
//
// Multi-segment support: a .m4a container closes when AVAudioRecorder
// stops, so "pause and keep talking later" can't just resume the same
// file — each start()/stopSegment() pair produces one segment file.
// Segments are NOT merged on-device: AVAssetExportSession (needed to
// concatenate them into one file) is entirely unavailable on watchOS —
// every AVAssetExportPreset* constant is explicitly API_UNAVAILABLE(watchos)
// in the SDK, regardless of deployment target. Merging happens on the
// iPhone side instead (PhoneConnectivityService), which has full
// AVFoundation — the Watch's only job is to hand over ordered segments.
final class WatchAudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var segmentURLs: [URL] = []

    var hasPendingSegments: Bool { !segmentURLs.isEmpty }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.record()
        self.recorder = recorder
        self.isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    /// Ends the current segment and holds onto it. Call start() again to
    /// record another segment appended to the same session, or
    /// finishSegments() to collect everything recorded since the last
    /// finishSegments()/discard() call.
    func stopSegment() {
        let finishedURL = recorder?.url
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        if let finishedURL {
            segmentURLs.append(finishedURL)
        }
        recorder = nil
    }

    /// Returns all segments recorded since the last finishSegments()/
    /// discard() call, in recording order, and clears session state.
    /// The caller (ContentView) owns the returned files from here —
    /// WatchConnectivityService hands each one to WCSession, which reads
    /// straight from disk during the transfer, so cleanup happens once
    /// the transfer completes, not here.
    func finishSegments() -> [URL] {
        let segments = segmentURLs
        segmentURLs = []
        elapsedSeconds = 0
        return segments
    }

    /// Discards all segments recorded since the last finishSegments()/
    /// discard() without sending anything.
    func discard() {
        for url in segmentURLs { try? FileManager.default.removeItem(at: url) }
        segmentURLs = []
        elapsedSeconds = 0
        recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
}
