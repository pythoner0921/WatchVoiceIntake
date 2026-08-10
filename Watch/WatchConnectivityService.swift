import Foundation
import WatchConnectivity

// Hands recorded segments to the OS-managed transfer queue instead of
// uploading directly from the Watch — see the feasibility report's D
// section for why (standalone Watch networking is documented as
// unreliable; transferFile survives the Watch app being backgrounded or
// killed mid-transfer, a raw URLSession upload from watchOS is not proven
// to). Mirrors VivaDicta's WatchConnectivityService.swift.
//
// A "note" can be multiple recorded segments (user paused and kept
// talking) — since watchOS can't merge them into one file itself (see
// WatchAudioRecorder), each segment is sent as its own transferFile call,
// tagged with enough metadata for the iPhone side to reassemble them in
// order and know when it's received the whole set.
final class WatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    @Published var pendingTransferCount = 0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Restore anything still queued from before the app relaunched —
        // outstandingFileTransfers survives across app restarts because
        // it's tracked by watchOS itself, not by this class's own state.
        DispatchQueue.main.async {
            self.pendingTransferCount = session.outstandingFileTransfers.count
        }
    }

    /// Sends every segment of one recording session, in order, each
    /// tagged with a shared sessionId + its position + the total segment
    /// count so PhoneConnectivityService knows when it has all of them.
    func send(segments: [URL], sessionId: String) {
        guard WCSession.default.activationState == .activated else {
            print("[WatchConnectivityService] session not activated, cannot send yet")
            return
        }
        let createdAt = ISO8601DateFormatter().string(from: Date())
        for (index, url) in segments.enumerated() {
            WCSession.default.transferFile(url, metadata: [
                "sessionId": sessionId,
                "sequenceIndex": index,
                "segmentCount": segments.count,
                "createdAt": createdAt,
            ])
        }
        pendingTransferCount = WCSession.default.outstandingFileTransfers.count
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            self.pendingTransferCount = session.outstandingFileTransfers.count
        }
        if let error {
            print("[WatchConnectivityService] transfer failed: \(error.localizedDescription)")
        }
    }
}
