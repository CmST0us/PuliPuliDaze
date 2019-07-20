import Foundation

public class PuliPuliDownloader: NSObject, VideoDownloaderDelegate {
    
    public var downloadItem: [(Int, VideoQuality)] = []
    public var maxConcurrentOperationCount: Int {
        set {
            self.downloader.maxConcurrentOperationCount = newValue
        }
        
        get {
            return self.downloader.maxConcurrentOperationCount
        }
    }
    
    var videoInfo: VideoInfo!
    var avNumber: Int = 0
    
    lazy var downloader: VideoDownloader = {
        let d = VideoDownloader()
        d.delegate = self
        return d
    }()
    
    public init(av: Int) {
        self.avNumber = av
    }
    
    public func work() {
        self.downloader.start()
    }
    
    public func fetchVideoInfo() {
        let videoInfo = VideoInfo(av: self.avNumber)
        let (ret, _) = videoInfo.fetchInfo()
        if (ret) {
            print("Video \(videoInfo.title) Has Pages:")
            videoInfo.pagesTitle.enumerated().forEach { (i) in
                print("     \(i.offset): \(i.element)")
            }
            self.videoInfo = videoInfo
        }
    }
    
    public func downloader(_ downloader: VideoDownloader, didTriggerEvent: VideoDownloaderEvent) {
        if (didTriggerEvent == .CanAddTask) {
            if (self.downloadItem.count > 0) {
                let item = self.downloadItem.removeFirst()
                let page = VideoPageInfo(videoItem: self.videoInfo.videoPages[item.0])
                page.fetchDownloadURL(quality: item.1)
                for downloadUrl in page.downloadURL {
                    downloader.addTask(url: downloadUrl, videoItem: page.videoItem)
                }
            }
        }
    }
}
