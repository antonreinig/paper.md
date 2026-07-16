import Foundation

final class FileObservationPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let onChange: @Sendable () -> Void
    private let onMove: @Sendable (URL) -> Void

    init(url: URL, onChange: @escaping @Sendable () -> Void, onMove: @escaping @Sendable (URL) -> Void) {
        presentedItemURL = url
        presentedItemOperationQueue = OperationQueue()
        presentedItemOperationQueue.name = "com.antonreinig.PaperMD.file-presenter"
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        self.onChange = onChange
        self.onMove = onMove
        super.init()
    }

    func presentedItemDidChange() { onChange() }
    func presentedItemDidMove(to newURL: URL) { onMove(newURL) }
}
