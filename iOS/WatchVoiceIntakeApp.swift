import SwiftUI

@main
struct WatchVoiceIntakeApp: App {
    // Starts listening for files the Watch sends over as soon as the phone
    // app launches — this app has no real UI of its own in Phase 1, it's
    // purely the network-capable relay the Watch can't reliably be on its
    // own (see the feasibility report's section C/D for why).
    @StateObject private var connectivity = PhoneConnectivityService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var connectivity: PhoneConnectivityService

    var body: some View {
        VStack(spacing: 16) {
            Text("Voice Intake")
                .font(.title2).bold()
            Text("Relays voice notes from your Watch to Research OS.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if connectivity.pendingCount > 0 {
                Text("\(connectivity.pendingCount) pending upload(s)")
                    .font(.footnote)
            }
        }
        .padding()
    }
}
