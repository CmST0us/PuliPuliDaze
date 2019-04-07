import Foundation

public class VideoDownloader: NSObject{
    
    var downloadingTask: [VideoDownloadTask] = []
    var waitingTask: [VideoDownloadTask] = []
    
    public var maxConcurrentOperationCount: Int = 1
    
    public func addTask(url: URL, videoItem: VideoJSON.VideoData.VideoItem) {
        let task = VideoDownloadTask(url: url, videoItem: videoItem)
        self.waitingTask.append(task)
    }
    
    public func videoItemIndexInWaitingQueue(videoItem: VideoJSON.VideoData.VideoItem) -> Int {
        var index = -1
        self.waitingTask.enumerated().forEach { (task) in
            
            if task.element.videoItem.cid == videoItem.cid! {
                index = task.offset
            }
        }
        return index
    }
    
    public func videoItemIndexInDownloadingQueue(videoItem: VideoJSON.VideoData.VideoItem) -> Int {
        var index = -1
        self.downloadingTask.enumerated().forEach { (task) in
            
            if task.element.videoItem.cid == videoItem.cid! {
                index = task.offset
            }
        }
        return index
    }
    
    func resumeDownloadingTask(indexInDownloadingQueue: Int) {
        let task = self.downloadingTask[indexInDownloadingQueue]
        task.task.resume()
    }
    
    func resumeWaitingTask(indexInWaitingQueue: Int) {
        let task = self.waitingTask[indexInWaitingQueue]
        self.downloadingTask.append(task)
        self.waitingTask.remove(at: indexInWaitingQueue)
        task.task.resume()
    }
    
    public func resumeTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let waitingQueueIndex = self.videoItemIndexInWaitingQueue(videoItem: videoItem)
        let downloadingQueueIndex = self.videoItemIndexInDownloadingQueue(videoItem: videoItem)
        
        if (downloadingQueueIndex >= 0) {
            self.resumeDownloadingTask(indexInDownloadingQueue: downloadingQueueIndex)
        } else if (waitingQueueIndex == -1 && downloadingQueueIndex == -1) {
            // invaild
            return
        } else if (waitingQueueIndex >= 0) {
            self.resumeWaitingTask(indexInWaitingQueue: waitingQueueIndex)
        }
    }
    
    public func pauseTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let waitingQueueIndex = self.videoItemIndexInWaitingQueue(videoItem: videoItem)
        let downloadingQueueIndex = self.videoItemIndexInDownloadingQueue(videoItem: videoItem)
        if (waitingQueueIndex >= 0) {
            self.waitingTask[waitingQueueIndex].task.suspend()
        }
        if (downloadingQueueIndex >= 0) {
            self.downloadingTask[downloadingQueueIndex].task.suspend()
        }
    }
    
    public func cancelTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let waitingQueueIndex = self.videoItemIndexInWaitingQueue(videoItem: videoItem)
        let downloadingQueueIndex = self.videoItemIndexInDownloadingQueue(videoItem: videoItem)
        
        if (waitingQueueIndex >= 0) {
            self.waitingTask[waitingQueueIndex].task.cancel()
            self.waitingTask.remove(at: waitingQueueIndex)
        }
        
        if (downloadingQueueIndex >= 0) {
            self.downloadingTask[downloadingQueueIndex].task.cancel()
            self.downloadingTask.remove(at: downloadingQueueIndex)
        }
    }
    
}
