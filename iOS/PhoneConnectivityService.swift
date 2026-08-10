import Foundation
import WatchConnectivity
import AVFoundation

// Receives audio segments the Watch sends via WCSession.transferFile — the
// OS-managed transfer queue is why this exists instead of the Watch
// uploading directly (see the feasibility report, section D: standalone
// Watch networking is documented as unreliable, transferFile survives the
// Watch app being backgrounded/killed mid-transfer in a way a raw
// URLSession upload from watchOS is not).
//
// A recording session can be multiple segments (user tapped "继续说" on
// the Watch instead of finishing) — the Watch can't merge them into one
// file itself (AVAssetExportSession is entirely unavailable on watchOS,
// see WatchAudioRecorder's comment), so this class collects segments by
// sessionId, and once it has every segment a session's metadata says to
// expect, merges them here on iOS (where AVAssetExportSession works)
// into the single file that actually gets uploaded.
//
// Phase 1-3 scope: receive, group, merge, count. Actually enqueuing +
// uploading the merged file to the AI Intake server is Phase 4
// (UploadQueueManager, not built yet) — kept separate so this class's
// only job is "turn Watch segments into one finished recording," not
// also know about HTTP/retry logic.
final class PhoneConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    @Published var pendingCount = 0
    @Published var mergedCount = 0

    private struct PendingSession {
        var segments: [Int: URL] = [:]
        var expectedCount: Int
    }

    private var pendingSessions: [String: PendingSession] = [:]
    private let queue = DispatchQueue(label: "com.shuyinlab.watchvoiceintake.phoneconnectivity")

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Required by the protocol — nothing to restore here; in-flight
        // transfers resume automatically and land in didReceive file:.
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // A new Watch could be paired later — re-activate so this phone
        // keeps receiving from whichever Watch is currently paired.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WCSessionFile's fileURL points at a temp location the system
        // deletes once this method returns, so the segment has to be
        // copied out synchronously, before we return, not just referenced.
        guard let metadata = file.metadata,
              let sessionId = metadata["sessionId"] as? String,
              let sequenceIndex = metadata["sequenceIndex"] as? Int,
              let segmentCount = metadata["segmentCount"] as? Int else {
            print("[PhoneConnectivityService] received file with missing/malformed metadata, dropping")
            return
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sessionId)-\(sequenceIndex)")
            .appendingPathExtension("m4a")
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: dest)
        } catch {
            print("[PhoneConnectivityService] failed to copy received segment: \(error.localizedDescription)")
            return
        }

        DispatchQueue.main.async { self.pendingCount += 1 }

        queue.async { [weak self] in
            guard let self else { return }
            var pending = self.pendingSessions[sessionId] ?? PendingSession(expectedCount: segmentCount)
            pending.segments[sequenceIndex] = dest
            self.pendingSessions[sessionId] = pending

            guard pending.segments.count == pending.expectedCount else { return }
            self.pendingSessions.removeValue(forKey: sessionId)
            let orderedURLs = (0..<pending.expectedCount).compactMap { index in pending.segments[index] }

            Task {
                let merged = await self.merge(segments: orderedURLs, sessionId: sessionId)
                for url in orderedURLs { try? FileManager.default.removeItem(at: url) }
                guard let merged else {
                    print("[PhoneConnectivityService] merge failed for session \(sessionId)")
                    return
                }
                print("[PhoneConnectivityService] merged \(orderedURLs.count) segment(s) into \(merged.lastPathComponent)")
                await MainActor.run { self.mergedCount += 1 }
                // Phase 4 replaces this with UploadQueueManager.enqueue(file: merged) —
                // moving the merged recording into the persistent pending-upload
                // queue (see the feasibility report's K section) instead of just
                // leaving it on disk.
            }
        }
    }

    /// Concatenates segments (already in the right order) into a single
    /// m4a file. Single-segment sessions (the common case — most notes
    /// are one uninterrupted recording) skip AVAssetExportSession
    /// entirely since there's nothing to concatenate.
    private func merge(segments: [URL], sessionId: String) async -> URL? {
        guard !segments.isEmpty else { return nil }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("merged-\(sessionId)")
            .appendingPathExtension("m4a")

        if segments.count == 1 {
            try? FileManager.default.copyItem(at: segments[0], to: outputURL)
            return FileManager.default.fileExists(atPath: outputURL.path) ? outputURL : nil
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }

        var cursor = CMTime.zero
        for url in segments {
            let asset = AVURLAsset(url: url)
            guard let assetTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                  let duration = try? await asset.load(.duration) else { continue }
            try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: assetTrack, at: cursor)
            cursor = cursor + duration
        }

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }
        export.outputURL = outputURL
        export.outputFileType = .m4a

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { continuation.resume() }
        }
        return export.status == .completed ? outputURL : nil
    }
}
