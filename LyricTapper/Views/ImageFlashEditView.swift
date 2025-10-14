import SwiftUI
import AppKit

struct ImageFlashEditView: View {
    @ObservedObject var app: AppState
    @State private var nudgeFrames: Int = 0
    private let decodeCache = ImageDecodeCache(targetWidth: 160)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Stepper("Nudge (frames @30fps): \(nudgeFrames)", value: $nudgeFrames, in: -150...150, step: 1)
                Button("Apply Nudge Start") { applyNudge(startDelta: framesToSeconds(nudgeFrames), endDelta: 0) }
                Button("Apply Nudge End") { applyNudge(startDelta: 0, endDelta: framesToSeconds(nudgeFrames)) }
                Spacer()
                Button("Continue to Export") { app.stage = .imageExport }
            }

            Table(app.project.imageIntervals) {
                TableColumn("#") { item in
                    Text(String(app.project.imageIntervals.firstIndex(where: { $0.start == item.start && $0.end == item.end }) ?? 0 + 1))
                }
                TableColumn("Thumb") { item in
                    if let url = resolveURL(item.fileID), let cg = decodeCache.decodedScaledToWidth(url: url) {
                        Image(nsImage: NSImage(cgImage: cg, size: .zero))
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipped()
                    } else { Color.gray.frame(width: 80, height: 80) }
                }
                TableColumn("Image") { item in
                    Text(app.project.imageCatalog[item.fileID]?.originalFilename ?? "")
                }
                TableColumn("Start") { item in Text(String(format: "%.3f", item.start)) }
                TableColumn("End") { item in Text(String(format: "%.3f", item.end)) }
                TableColumn("Actions") { item in
                    HStack(spacing: 8) {
                        Menu("Swap…") {
                            ForEach(Array(app.project.imageCatalog.keys), id: \.self) { candidate in
                                let name = app.project.imageCatalog[candidate]?.originalFilename ?? "Unknown"
                                Button(name) { swapInterval(item: item, newID: candidate) }
                            }
                        }
                        Button("Delete") { deleteInterval(item: item) }
                    }
                }
            }
            .frame(minHeight: 240)
        }
        .padding()
        .onAppear(perform: computeIntervalsIfNeeded)
    }

    private func framesToSeconds(_ frames: Int) -> Double { Double(frames) / 30.0 }

    private func computeIntervalsIfNeeded() {
        if app.project.imageIntervals.isEmpty, !app.project.imageTapTimestamps.isEmpty {
            app.project.imageIntervals = TimingService.computeImageIntervals(
                taps: app.project.imageTapTimestamps,
                audioDuration: app.project.audioDuration,
                imageOrder: app.project.imageFileIDs
            )
        }
    }

    private func applyNudge(startDelta: Double, endDelta: Double) {
        var updated: [ImageInterval] = []
        var lastEnd = 0.0
        for var it in app.project.imageIntervals {
            it.start = max(0.0, it.start + startDelta)
            it.end = max(it.start, it.end + endDelta)
            it.start = max(it.start, lastEnd)
            lastEnd = it.end
            updated.append(it)
        }
        app.project.imageIntervals = updated
    }

    private func resolveURL(_ id: ImageFileID) -> URL? {
        BookmarkService.resolveBookmark(id.urlBookmark)
    }

    private func swapInterval(item: ImageInterval, newID: ImageFileID) {
        guard let idx = app.project.imageIntervals.firstIndex(where: { $0.start == item.start && $0.end == item.end && $0.fileID == item.fileID }) else { return }
        app.project.imageIntervals[idx].fileID = newID
    }

    private func deleteInterval(item: ImageInterval) {
        guard let idx = app.project.imageIntervals.firstIndex(where: { $0.start == item.start && $0.end == item.end && $0.fileID == item.fileID }) else { return }
        var intervals = app.project.imageIntervals
        let deleted = intervals[idx]
        if intervals.count == 1 {
            intervals.removeAll()
            app.project.imageIntervals = intervals
            return
        }
        if idx > 0 {
            intervals[idx - 1].end = max(intervals[idx - 1].end, deleted.end)
        }
        intervals.remove(at: idx)
        if idx > 0 && idx < intervals.count {
            let newEnd = intervals[idx - 1].end
            intervals[idx].start = max(intervals[idx].start, newEnd)
        } else if idx == 0 && !intervals.isEmpty {
            intervals[0].start = min(intervals[0].start, deleted.start)
        }
        app.project.imageIntervals = intervals
    }
}


