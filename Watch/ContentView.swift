import SwiftUI

enum RecordingState {
    case idle
    case recording
    case paused
    case sending
    case sent
}

// 未录音 / 录音中 / 暂停(继续说 or 完成) / Uploading... / Uploaded ✓.
// Pausing instead of sending immediately on Stop lets the user add more
// to the same note before it's sent — one upload/note per finished
// thought, not one per Stop tap. No recording list, no settings, no
// playback — still the single-purpose "AI Intake Recorder" the
// feasibility report scoped Phase 1-2 to.
struct ContentView: View {
    @StateObject private var recorder = WatchAudioRecorder()
    @StateObject private var connectivity = WatchConnectivityService()
    @State private var state: RecordingState = .idle
    @State private var sessionId: String?

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
                    pauseRecording()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            case .paused:
                Text(formattedElapsed)
                    .font(.system(.title3, design: .monospaced))
                Button {
                    resumeRecording()
                } label: {
                    Label("继续说", systemImage: "mic.fill")
                }
                .buttonStyle(.bordered)
                Button {
                    finishAndUpload()
                } label: {
                    Label("完成", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

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
            sessionId = UUID().uuidString
            state = .recording
        } catch {
            print("[ContentView] failed to start recording: \(error.localizedDescription)")
        }
    }

    private func pauseRecording() {
        recorder.stopSegment()
        state = .paused
    }

    private func resumeRecording() {
        do {
            try recorder.start()
            state = .recording
        } catch {
            print("[ContentView] failed to resume recording: \(error.localizedDescription)")
        }
    }

    private func finishAndUpload() {
        let segments = recorder.finishSegments()
        guard !segments.isEmpty, let sessionId else {
            state = .idle
            return
        }
        state = .sending
        connectivity.send(segments: segments, sessionId: sessionId)
        self.sessionId = nil
        // transferFile is fire-and-forget from here — WatchConnectivityService
        // tracks completion via the WCSessionDelegate callback, not a return
        // value, so this view can't wait on the real ACK yet. Phase 4 wires
        // a proper "server confirmed receipt" signal back to this state
        // instead of the fixed delay below, which is a Phase 1-3 placeholder
        // only so the UI has somewhere to go after Finish.
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
