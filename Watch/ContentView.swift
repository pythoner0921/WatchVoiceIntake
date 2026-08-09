import SwiftUI

enum RecordingState {
    case idle
    case recording
    case sending
    case sent
}

// Matches the exact 4-state mockup from the feasibility report's section
// 2 (未录音 / 录音中 / Uploading... / Uploaded ✓) — deliberately nothing
// more than that. No recording list, no settings, no playback — this is
// the single-purpose "AI Intake Recorder" the report scoped Phase 1-2 to.
struct ContentView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var connectivity = WatchConnectivityService()
    @State private var state: RecordingState = .idle

    var body: some View {
        VStack(spacing: 12) {
            switch state {
            case .idle:
                Button {
                    startRecording()
                } label: {
                    Label("开始录音", systemImage: "circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)

            case .recording:
                Text(formattedElapsed)
                    .font(.system(.title2, design: .monospaced))
                Button {
                    stopRecording()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            case .sending:
                ProgressView("Uploading…")

            case .sent:
                Label("Uploaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
    }

    private var formattedElapsed: String {
        let m = recorder.elapsedSeconds / 60
        let s = recorder.elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startRecording() {
        do {
            try recorder.start()
            state = .recording
        } catch {
            print("[ContentView] failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        guard let url = recorder.stop() else {
            state = .idle
            return
        }
        state = .sending
        connectivity.send(fileURL: url)
        // transferFile is fire-and-forget from here — WatchConnectivityService
        // tracks completion via the WCSessionDelegate callback, not a return
        // value, so this view can't wait on the real ACK yet. Phase 4 wires
        // a proper "server confirmed receipt" signal back to this state
        // instead of the fixed delay below, which is a Phase 1/2 placeholder
        // only so the UI has somewhere to go after Stop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            state = .sent
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                state = .idle
            }
        }
    }
}

#Preview {
    ContentView()
}
