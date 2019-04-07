import Foundation

public enum VideoDownloaderEvent {
    case CanAddTask
    case TaskFinish
}

public protocol VideoDownloaderDelegate: NSObjectProtocol {
    func downloader(_ downloader: VideoDownloader, didTriggerEvent: VideoDownloaderEvent)
}

public class VideoDownloader: NSObject{
    
    var pausingQueue:[VideoDownloadTask] = []
    var downloadingQueue: [VideoDownloadTask] = []
    var waitingQueue: [VideoDownloadTask] = []
    
    public weak var delegate: VideoDownloaderDelegate? = nil
    
    public var maxConcurrentOperationCount: Int = 1
    
    public func start() {
        let canAddCount = maxConcurrentOperationCount - self.downloadingQueue.count
        for _ in 0..<canAddCount {
            if (self.delegate != nil) {
                self.delegate?.downloader(self, didTriggerEvent: .CanAddTask)
            }
        }
    }
    
    public func stop() {
        
    }
    
    public func addTask(url: URL, videoItem: VideoJSON.VideoData.VideoItem) {
        let task = VideoDownloadTask(url: url, videoItem: videoItem, downloader: self)
        self.waitingQueue.append(task)
        if (downloadingQueue.count < maxConcurrentOperationCount) {
            resumeWaitingTask(videoItem: videoItem)
        }
    }
    
    public func videoItemIndexInQueue(_ queue: [VideoDownloadTask], videoItem: VideoJSON.VideoData.VideoItem) -> Int {
        var index = -1
        queue.enumerated().forEach { (task) in
            if task.element.videoItem.cid == videoItem.cid! {
                index = task.offset
            }
        }
        return index
    }
    
    // MARK: - Cancel Method
    public func cancelTask(videoItem: VideoJSON.VideoData.VideoItem) {
        var index = -1
        index = self.videoItemIndexInQueue(self.pausingQueue, videoItem: videoItem)
        if (index >= 0) {
            self.pausingQueue[index].task.cancel()
            self.pausingQueue.remove(at: index)
        }
        
        index = self.videoItemIndexInQueue(self.downloadingQueue, videoItem: videoItem)
        if (index >= 0) {
            self.downloadingQueue[index].task.cancel()
            self.downloadingQueue.remove(at: index)
        }
        
        index = self.videoItemIndexInQueue(self.waitingQueue, videoItem: videoItem)
        if (index >= 0) {
            self.waitingQueue[index].task.cancel()
            self.waitingQueue.remove(at: index)
        }
        
        if (self.downloadingQueue.count < self.maxConcurrentOperationCount &&
            self.waitingQueue.count > 0) {
            self.resumeWaitingTask(videoItem: self.waitingQueue[0].videoItem)
        } else {
            if (self.delegate != nil) {
                self.delegate?.downloader(self, didTriggerEvent: .CanAddTask)
            }
        }
    }
    
    // MARK: - Downloading Queue Method
    public func pauseDownloadingTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let indexInDownloadingQueue = self.videoItemIndexInQueue(self.downloadingQueue, videoItem: videoItem)
        
        let task = self.downloadingQueue[indexInDownloadingQueue]
        task.task.suspend()
        
        self.pausingQueue.append(task)
        self.downloadingQueue.remove(at: indexInDownloadingQueue)
        
        if (self.waitingQueue.count > 0) {
            self.resumeWaitingTask(videoItem: self.waitingQueue[0].videoItem)
        } else {
            if (self.delegate != nil) {
                self.delegate?.downloader(self, didTriggerEvent: .CanAddTask)
            }
        }
    }
    
    public func finishDownloadingTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let indexInDownloadingQueue = self.videoItemIndexInQueue(self.downloadingQueue, videoItem: videoItem)
        
        self.downloadingQueue.remove(at: indexInDownloadingQueue)
        
        let task = self.waitingQueue.popLast()
        if (task != nil) {
            self.downloadingQueue.append(task!)
            task!.task.resume()
        }
        
        if (self.delegate != nil) {
            self.delegate?.downloader(self, didTriggerEvent: .TaskFinish)
        }
        
        if (self.downloadingQueue.count < self.maxConcurrentOperationCount) {
            if (self.delegate != nil) {
                self.delegate?.downloader(self, didTriggerEvent: .CanAddTask)
            }
        }
    }
    
    // MARK: - Pausing Queue Method
    public func resumePausingTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let indexInPausingQueue = self.videoItemIndexInQueue(self.pausingQueue, videoItem: videoItem)
        
        let task = self.pausingQueue[indexInPausingQueue]
        self.waitingQueue.append(task)
        self.pausingQueue.remove(at: indexInPausingQueue)
    }
    
    // MARK: - Waiting Queue Method
    public func pauseWaitingTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let indexInWaitingQueue = self.videoItemIndexInQueue(self.waitingQueue, videoItem: videoItem)
        
        let task = self.waitingQueue[indexInWaitingQueue]
        task.task.suspend()
        self.pausingQueue.append(task)
        self.waitingQueue.remove(at: indexInWaitingQueue)
    }
    
    public func resumeWaitingTask(videoItem: VideoJSON.VideoData.VideoItem) {
        if (self.downloadingQueue.count >= self.maxConcurrentOperationCount) {
            return
        }
        
        let indexInWaitingQueue = self.videoItemIndexInQueue(self.waitingQueue, videoItem: videoItem)
        let task = self.waitingQueue[indexInWaitingQueue]
        self.downloadingQueue.append(task)
        task.task.resume()
        self.waitingQueue.remove(at: indexInWaitingQueue)
    }
    
}
