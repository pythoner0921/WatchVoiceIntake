import Foundation
import WatchConnectivity

// Hands a recorded file to the OS-managed transfer queue instead of
// uploading directly from the Watch — see the feasibility report's D
// section for why (standalone Watch networking is documented as
// unreliable; transferFile survives the Watch app being backgrounded or
// killed mid-transfer, a raw URLSession upload from watchOS is not proven
// to). Mirrors VivaDicta's WatchConnectivityService.swift.
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

    func send(fileURL: URL) {
        guard WCSession.default.activationState == .activated else {
            print("[WatchConnectivityService] session not activated, cannot send yet")
            return
        }
        WCSession.default.transferFile(fileURL, metadata: [
            "recordingId": UUID().uuidString,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ])
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
