import Foundation
import WatchConnectivity

// Receives audio files the Watch sends via WCSession.transferFile — the
// OS-managed transfer queue is why this exists instead of the Watch
// uploading directly (see the feasibility report, section D: standalone
// Watch networking is documented as unreliable, transferFile survives the
// Watch app being backgrounded/killed mid-transfer in a way a raw
// URLSession upload from watchOS is not).
//
// Phase 1 scope: receive the file and count it. Actually enqueuing +
// uploading is Phase 4 (UploadQueueManager, not built yet) — kept separate
// so this class's only job is "be a reliable WCSession receiver," not also
// know about HTTP/retry logic.
final class PhoneConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    @Published var pendingCount = 0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Required by the protocol — nothing to do yet in Phase 1.
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // A new Watch could be paired later — re-activate so this phone
        // keeps receiving from whichever Watch is currently paired.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Phase 1: just prove the receive path works (count it, log it).
        // Phase 4 replaces this body with UploadQueueManager.enqueue(file:) —
        // moving the received file into the persistent pending-upload queue
        // (see the feasibility report's K section) instead of just counting.
        DispatchQueue.main.async {
            self.pendingCount += 1
        }
        print("[PhoneConnectivityService] received file: \(file.fileURL.lastPathComponent)")
    }
}
