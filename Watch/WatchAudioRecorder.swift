import Foundation
import AVFoundation

// Records to a temp .m4a file. Deliberately close to VivaDicta's
// WatchAudioRecorder.swift (see the feasibility report's D section) —
// AVAudioRecorder, not AVAudioEngine, is the simpler right tool for
// "record until stopped, hand back a file," and that project's approach
// is a proven, minimal reference for exactly this.
final class WatchAudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var lastRecordingURL: URL?

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
        self.lastRecordingURL = url
        self.isRecording = true
        self.elapsedSeconds = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    /// Returns the recorded file's URL, or nil if nothing was recorded
    /// (e.g. stop() called without a prior successful start()).
    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return lastRecordingURL
    }
}
