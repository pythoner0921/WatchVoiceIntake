import Foundation

// Persists pending uploads to disk under Documents (survives app
// relaunch/kill, unlike tmp) so a recording merged while the phone has no
// network isn't lost, only delayed — see the feasibility report's K
// section: UUID, retry_count, upload_status, idempotency key. The
// recordingId IS the idempotency key: server/watch.js's handleWatchVoiceUpload
// uses it as the pending-note row's primary key, so a retried upload that
// actually succeeded server-side the first time (client just never saw
// the response) produces one note, not two.
final class UploadQueueManager: ObservableObject {
    static let shared = UploadQueueManager()

    private struct QueueEntry: Codable {
        let recordingId: String
        var retryCount: Int
        let createdAt: Date
    }

    @Published private(set) var queuedCount = 0

    private let queueDir: URL
    private let manifestURL: URL
    private var entries: [QueueEntry] = []
    private let queue = DispatchQueue(label: "com.shuyinlab.watchvoiceintake.uploadqueue")
    private var isFlushing = false

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        queueDir = docs.appendingPathComponent("PendingUploads", isDirectory: true)
        manifestURL = queueDir.appendingPathComponent("manifest.json")
        try? FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        loadManifest()
    }

    private func audioURL(for recordingId: String) -> URL {
        queueDir.appendingPathComponent("\(recordingId).m4a")
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let loaded = try? JSONDecoder().decode([QueueEntry].self, from: data) else { return }
        entries = loaded
        queuedCount = entries.count
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    /// Moves the merged recording into persistent storage and queues it
    /// for upload. Safe to call with no network — flush() picks it up
    /// once one's available (called again on next enqueue, app foreground,
    /// or whatever else triggers WatchVoiceIntakeApp's retry hook).
    func enqueue(file: URL, recordingId: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let dest = self.audioURL(for: recordingId)
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: file, to: dest)
            } catch {
                print("[UploadQueueManager] failed to persist \(recordingId): \(error.localizedDescription)")
                return
            }
            self.entries.append(QueueEntry(recordingId: recordingId, retryCount: 0, createdAt: Date()))
            self.saveManifest()
            DispatchQueue.main.async { self.queuedCount = self.entries.count }
            self.flushLocked()
        }
    }

    /// Attempts to upload every queued recording, one at a time. Safe to
    /// call repeatedly — a flush already in progress is a no-op, and
    /// entries that upload successfully are removed as they go so a
    /// crash mid-flush just resumes with whatever's left next time.
    func flush() {
        queue.async { [weak self] in self?.flushLocked() }
    }

    /// Must only be called from `queue`.
    private func flushLocked() {
        guard !isFlushing else { return }
        guard AuthSession.shared.token != nil else { return }
        isFlushing = true
        defer { isFlushing = false }

        for entry in entries {
            let ok = uploadSync(entry)
            if ok {
                entries.removeAll { $0.recordingId == entry.recordingId }
                try? FileManager.default.removeItem(at: audioURL(for: entry.recordingId))
            } else if let idx = entries.firstIndex(where: { $0.recordingId == entry.recordingId }) {
                entries[idx].retryCount += 1
            }
        }
        saveManifest()
        let remaining = entries.count
        DispatchQueue.main.async { self.queuedCount = remaining }
    }

    /// Blocking (within `queue`, never the main thread) upload of one
    /// entry — a DispatchSemaphore bridges URLSession's callback-based API
    /// into this synchronous loop, which is what makes flushLocked() upload
    /// strictly one recording at a time instead of racing several requests
    /// (and, more importantly, what keeps `entries` mutation single-threaded
    /// without needing a second lock).
    private func uploadSync(_ entry: QueueEntry) -> Bool {
        guard let token = AuthSession.shared.token else { return false }
        let audioPath = audioURL(for: entry.recordingId)
        guard let audioData = try? Data(contentsOf: audioPath) else {
            // File's gone (e.g. Documents got wiped by a reinstall) —
            // nothing left to retry, so this entry should NOT stay queued
            // forever; treat as "handled" so it gets dropped.
            return true
        }

        var request = URLRequest(url: AuthSession.apiBaseURL.appendingPathComponent("api/watch/voice"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("recordingId", entry.recordingId)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), error == nil {
                success = true
            } else if let error {
                print("[UploadQueueManager] upload failed for \(entry.recordingId): \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse {
                print("[UploadQueueManager] upload failed for \(entry.recordingId): HTTP \(http.statusCode)")
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return success
    }
}
