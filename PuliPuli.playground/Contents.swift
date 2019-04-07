import Cocoa
import CommonCrypto

let kUserAgent = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"
let kAPIBase = "https://api.bilibili.com/x/web-interface/view?aid="
let kAPPKey = "iVGUTjsxvpLeuDCf"
let kSec = "aHRmhWMLkdeMuILqORnYZocwMBpMEOdt"

struct VideoListJSON: Codable {
    struct VideoDownloadURL : Codable {
        var url: String?
    }
    var durl: [VideoDownloadURL]?
}

struct VideoJSON : Codable {
    
    struct VideoData : Codable{
        
        struct VideoItem : Codable {
            var cid: Int?
            var part: String?
            var page: Int?
        }
        
        var pages: [VideoItem]?
        var title: String?
        var aid: Int?
    }

    var data: VideoData?
}

enum VideoQuality : Int {
    case q1080PP = 112
    case q1080P = 80
    case q720P = 64
    case q480P = 32
    case q360P = 15
}

class VideoInfo {
    var info: VideoJSON.VideoData!
    var videoPages: [VideoJSON.VideoData.VideoItem] = []
    var avNumber: Int
    
    var title: String {
        return info.title!
    }
    
    init(av: Int) {
        self.avNumber = av
    }
    
    func fetchInfo() -> (Bool, Error?) {
        var request = URLRequest(url: URL(string: kAPIBase + "\(self.avNumber)")!)
        request.addValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _, err) = URLSession.shared.syncDataTask(request: request)
        if (data == nil) {
            return (false, err)
        }
        
        let jsonDecoder = JSONDecoder()
        let videoJson = try? jsonDecoder.decode(VideoJSON.self, from: data!)
        if (videoJson == nil) {
            return (false, err)
        }
        
        self.videoPages = videoJson?.data?.pages ?? []
        self.info = videoJson!.data!
        if (self.videoPages.count > 0) {
            return (true, nil)
        }
        return (false, nil)
    }
    
    var pagesTitle: [String] {
        return self.videoPages.map({ (item) -> String in
            return item.part!
        })
    }
    
}

class VideoPageInfo {
    
    var downloadURL: [URL] = []
    
    var videoItem: VideoJSON.VideoData.VideoItem
    var quality: VideoQuality = .q480P
    
    var downloadParam: String {
        return "appkey=\(kAPPKey)&cid=\(videoItem.cid ?? 0)&otype=json&qn=\(quality.rawValue)&quality=\(quality.rawValue)&type="
    }
    
    var refererURL: String {
        return kAPIBase + "/?p=\(videoItem.page ?? 0)"
    }
    
    var checkSum: String {
        return (self.downloadParam + kSec).md5
    }
    
    var downloadListRequestURL: String {
        return "https://interface.bilibili.com/v2/playurl?\(downloadParam)&sign=\(checkSum)"
    }
    
    lazy var downloadRequest: URLRequest = {
        var r = URLRequest(url: URL(string: self.downloadListRequestURL)!)
        r.setValue(self.refererURL, forHTTPHeaderField: "Referer")
        r.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        return r
    }()
    
    init(videoItem: VideoJSON.VideoData.VideoItem) {
        self.videoItem = videoItem
    }
    
    func fetchDownloadURL(quality: VideoQuality) -> (Bool, Error?){
        self.quality = quality
        
        let (data, _, err) = URLSession.shared.syncDataTask(request: self.downloadRequest)
        guard data != nil else {
            return (false, err)
        }
        
        let jsonDecoder = JSONDecoder()
        let videoList = try? jsonDecoder.decode(VideoListJSON.self, from: data!)
        if videoList == nil {
            return (false, nil)
        }
        
        self.downloadURL = videoList!.durl!.map({ (url) -> URL in
            return URL(string: url.url!)!
        })
        
        if (self.downloadURL.count > 0) {
            return (true, nil)
        }
        return (false, nil)
    }
}

class VideoDownloadTask: NSObject, URLSessionDownloadDelegate  {
    var url: URL
    var videoItem: VideoJSON.VideoData.VideoItem
    
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
        return kAPIBase + "/?p=\(videoItem.page ?? 0)"
    }
    
    var downloadRequest: URLRequest {
        var r = URLRequest(url: self.url)
        
        r.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        r.setValue("*/*", forHTTPHeaderField: "Accept")
        r.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        r.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        r.setValue("bytes=0-", forHTTPHeaderField: "Range")
        r.setValue(self.refererURL, forHTTPHeaderField: "Referer")
        r.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        r.setValue("keep-alive", forHTTPHeaderField: "Connection")
        return r
    }
    
    init(url: URL, videoItem: VideoJSON.VideoData.VideoItem) {
        self.url = url
        self.videoItem = videoItem
    }
    
    // MARK: - Download Delegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("\(self.videoItem.part ?? "") Download Finished, local at \(location.absoluteString)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("\(self.videoItem.part ?? "") Write \(bytesWritten) Bytes")
    }
}

class VideoDownloader: NSObject{
    
    var downloadingTask: [VideoDownloadTask] = []
    var waitingTask: [VideoDownloadTask] = []
    
    var maxConcurrentOperationCount: Int = 1
    
    func addTask(url: URL, videoItem: VideoJSON.VideoData.VideoItem) {
        let task = VideoDownloadTask(url: url, videoItem: videoItem)
        self.waitingTask.append(task)
    }
    
    func videoItemIndexInWaitingQueue(videoItem: VideoJSON.VideoData.VideoItem) -> Int {
        var index = -1
        self.waitingTask.enumerated().forEach { (task) in
            
            if task.element.videoItem.cid == videoItem.cid! {
                index = task.offset
            }
        }
        return index
    }
    
    func videoItemIndexInDownloadingQueue(videoItem: VideoJSON.VideoData.VideoItem) -> Int {
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
    
    func resumeTask(videoItem: VideoJSON.VideoData.VideoItem) {
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

    func pauseTask(videoItem: VideoJSON.VideoData.VideoItem) {
        let waitingQueueIndex = self.videoItemIndexInWaitingQueue(videoItem: videoItem)
        let downloadingQueueIndex = self.videoItemIndexInDownloadingQueue(videoItem: videoItem)
        if (waitingQueueIndex >= 0) {
            self.waitingTask[waitingQueueIndex].task.suspend()
        }
        if (downloadingQueueIndex >= 0) {
            self.downloadingTask[downloadingQueueIndex].task.suspend()
        }
    }
    
    func cancelTask(videoItem: VideoJSON.VideoData.VideoItem) {
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

let kTestAVNumber = 48323686
let downloader = VideoDownloader()
downloader.maxConcurrentOperationCount = 1

let videoInfo = VideoInfo(av: kTestAVNumber)
let (ret, _) = videoInfo.fetchInfo()
if (ret) {
    print("Ready to download \(videoInfo.title)")
    videoInfo.pagesTitle.enumerated().forEach { (i) in
        print("     \(i.offset): \(i.element)")
    }
}

let downloadPageIndex = 0
print("Select page \(downloadPageIndex)")

let page = VideoPageInfo(videoItem: videoInfo.videoPages[downloadPageIndex])
page.fetchDownloadURL(quality: .q480P)

downloader.addTask(url: page.downloadURL[0], videoItem: page.videoItem)
downloader.resumeTask(videoItem: page.videoItem)

DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(3)) {
    downloader.pauseTask(videoItem: page.videoItem)
    print("Pause Download")
    
    DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
        downloader.resumeTask(videoItem: page.videoItem)
        print("Resume Download")
    })
}


