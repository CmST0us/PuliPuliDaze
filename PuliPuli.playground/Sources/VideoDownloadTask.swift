import Foundation

public class VideoDownloadTask: NSObject, URLSessionDownloadDelegate  {
    var url: URL
    var order: Int = 0
    var videoItem: VideoJSON.VideoData.VideoItem
    weak var downloader: VideoDownloader?
    
    lazy var delegateQueue: OperationQueue = {
        return OperationQueue()
    }()
    
    lazy var session: URLSession = {
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: self.delegateQueue)
        return s
    }()
    
    lazy var task: URLSessionDownloadTask = {
        return self.session.downloadTask(with: self.downloadRequest)
    }()
    
    var refererURL: String {
        return Env.APIBase + "/?p=\(videoItem.page ?? 0)"
    }
    
    var downloadRequest: URLRequest {
        var r = URLRequest(url: self.url)
        r.setValue(Env.UserAgent, forHTTPHeaderField: "User-Agent")
        r.setValue("*/*", forHTTPHeaderField: "Accept")
        r.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        r.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        r.setValue("bytes=0-", forHTTPHeaderField: "Range")
        r.setValue(self.refererURL, forHTTPHeaderField: "Referer")
        r.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        r.setValue("keep-alive", forHTTPHeaderField: "Connection")
        return r
    }
    
    public init(url: (Int, URL), videoItem: VideoJSON.VideoData.VideoItem, downloader: VideoDownloader) {
        self.order = url.0
        self.url = url.1
        self.videoItem = videoItem
        self.downloader = downloader
    }
    
    // MARK: - Download Delegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("\(self.videoItem.part ?? "") Download Finished, local at \(location.absoluteString)")
        
        defer {
            self.downloader?.finishDownloadingTask(videoItem: self.videoItem)
        }
        
        let saveFilePath = Env.downloadPath + "/\(self.videoItem.part!)-\(String(self.order)).flv"
        let saveFileURL = URL(fileURLWithPath: saveFilePath)
        do {
            try FileManager.default.moveItem(at: location, to: saveFileURL)
        } catch {
            print("Save \(self.videoItem.part!) failed, \(error)")
        }
        print("Save to \(saveFilePath)")
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("\(self.videoItem.part ?? "") Write \(bytesWritten) Bytes, Process \(totalBytesWritten) / \(totalBytesExpectedToWrite) : \(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * Float(100))%")
    }
}
