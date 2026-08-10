import SwiftUI

@main
struct WatchVoiceIntakeApp: App {
    // Starts listening for files the Watch sends over as soon as the phone
    // app launches — this app has no real UI of its own in Phase 1, it's
    // purely the network-capable relay the Watch can't reliably be on its
    // own (see the feasibility report's section C/D for why).
    @StateObject private var connectivity = PhoneConnectivityService()
    @StateObject private var authSession = AuthSession.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authSession.isLoggedIn {
                    ContentView()
                        .environmentObject(connectivity)
                } else {
                    LoginView()
                }
            }
            .onAppear {
                // A recording merged while the app was closed / logged out
                // sits in UploadQueueManager's persistent queue until
                // there's both a token and a foreground app to retry from —
                // this is that retry point, not just "queued forever until
                // the next new recording happens to trigger enqueue()".
                UploadQueueManager.shared.flush()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connectivity: PhoneConnectivityService
    @ObservedObject var uploadQueue = UploadQueueManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Voice Intake")
                .font(.title2).bold()
            Text("Relays voice notes from your Watch to Research OS.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if connectivity.pendingCount > 0 {
                Text("\(connectivity.pendingCount) segment(s) received")
                    .font(.footnote)
            }
            if uploadQueue.queuedCount > 0 {
                Text("\(uploadQueue.queuedCount) recording(s) waiting to upload")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }
}
