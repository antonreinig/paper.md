import Foundation
import Darwin

final class DirectoryMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.antonreinig.PaperMD.directory-monitor")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var descriptors: [Int32] = []
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func watch(_ directories: [URL]) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked()
            for directory in directories {
                let descriptor = open(directory.path, O_EVTONLY)
                guard descriptor >= 0 else { continue }
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: descriptor,
                    eventMask: [.write, .delete, .rename, .extend, .attrib],
                    queue: self.queue
                )
                source.setEventHandler(handler: self.onChange)
                source.setCancelHandler { close(descriptor) }
                self.descriptors.append(descriptor)
                self.sources.append(source)
                source.resume()
            }
        }
    }

    func stop() { queue.async { [weak self] in self?.stopLocked() } }

    private func stopLocked() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        descriptors.removeAll()
    }

    deinit { sources.forEach { $0.cancel() } }
}
