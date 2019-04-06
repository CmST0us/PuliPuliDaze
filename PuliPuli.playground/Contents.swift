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

class Connector {
    typealias ConnectHandler = (_ videoJSON: VideoJSON?, _ err: Error?) -> Void
    
    var urlSession: URLSession! = nil
    
    let videoNumber: Int;
    init(_ videoNumber: Int) {
        self.videoNumber = videoNumber;
    }
    
    func connect(handler: @escaping ConnectHandler) {
        
        var request = URLRequest(url: URL(string: kAPIBase + "\(self.videoNumber)")!)
        request.addValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        
        self.urlSession = URLSession(configuration: URLSessionConfiguration.default)
        
        let task = self.urlSession.dataTask(with: request) { (data, res, err) in
            guard data != nil else {
                handler(nil, err)
                return
            }
            
            let jsonDecoder = JSONDecoder()
            let videoJson = try? jsonDecoder.decode(VideoJSON.self, from: data!)
            if (videoJson == nil) {
                handler(nil, err);
                return
            }
            handler(videoJson!, nil);
        }
        
        task.resume()
    }
}

enum VideoQuality : Int {
    case q1080PP = 112
    case q1080P = 80
    case q720P = 64
    case q480P = 32
    case q360P = 15
}

class GetDownloadURLTask: Operation, URLSessionDownloadDelegate {
    
    var videoItem: VideoJSON.VideoData.VideoItem!
    var quality: VideoQuality = .q360P
    lazy var downloadSem: DispatchSemaphore = {
       return DispatchSemaphore(value: 0)
    }()
    
    lazy var downloadOperationQueue = {
       return OperationQueue()
    }()
    
    lazy var downloadSession: URLSession = {
        let s = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: self.downloadOperationQueue)
        return s
    }()
    
    
    
    var downloadParam: String {
        return "appkey=\(kAPPKey)&cid=\(videoItem.cid ?? 0)&otype=json&qn=\(quality.rawValue)&quality=\(quality.rawValue)&type="
    }
    
    var checkSum: String {
        return (self.downloadParam + kSec).md5
    }
    
    var videoListAPIURL: String {
        return "https://interface.bilibili.com/v2/playurl?\(downloadParam)&sign=\(checkSum)"
    }
    
    lazy var downloadRequest: URLRequest = {
        var r = URLRequest(url: URL(string: self.videoListAPIURL)!)
        r.setValue(self.videoPageURL, forHTTPHeaderField: "Referer")
        r.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        return r
    }()
    
    func videoDownloadLists() -> [URL] {
        let (data, _, _) = URLSession.shared.syncDataTask(request: self.downloadRequest)
        guard data != nil else {
            return []
        }
        
        let jsonDecoder = JSONDecoder()
        let videoList = try? jsonDecoder.decode(VideoListJSON.self, from: data!)
        if videoList == nil {
            return []
        }
        
        return videoList!.durl!.map { (url) -> URL in
            return URL(string: url.url!)!
        }
    }
    

    
    override func main() {
        let downloadList = self.videoDownloadLists()
        
        for url in downloadList {
            let r = self.makeDownloadRequest(downloadURL: url)
            let task = self.downloadSession.downloadTask(with: r)
            task.resume()
        }
    }
}

class VideoDownloadTask {
    var url: URL
    var videoItem: VideoJSON.VideoData.VideoItem
    var quality: VideoQuality
    weak var session: URLSession?
    
    lazy var task: URLSessionDownloadTask = {
        return self.session!.downloadTask(with: self.downloadRequest)
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
    
    init(url: URL, videoItem: VideoJSON.VideoData.VideoItem, quality: VideoQuality, session: URLSession) {
        self.url = url
        self.videoItem = videoItem
        self.quality = quality
        self.session = session
    }
}

class VideoDownloader: NSObject, URLSessionDownloadDelegate {
    
    var downloadingTask: [VideoDownloadTask] = []
    var waitingTask: [VideoDownloadTask] = []
    
    lazy var delegateQueue: OperationQueue = {
       return OperationQueue()
    }()
    
    lazy var session: URLSession = {
        let s = URLSession(configuration: .default, delegate: self, delegateQueue: self.delegateQueue)
    }()
    
    var maxConcurrentOperationCount: Int = 1
    
    func addTask(url: URL, videoItem: VideoJSON.VideoData.VideoItem, quality: VideoQuality) {
        let task = VideoDownloadTask(url: url, videoItem: videoItem, quality: quality, session: self.session)
        self.waitingTask.append(task)
    }
    
    func resumeTask(videoItem: VideoJSON.VideoData.VideoItem) {
        self.waitingTask.forEach { (task) in
            if task.videoItem.cid == videoItem.cid! {
                print("""
                    Create Task:
                        cid: \(videoItem.cid ?? -1)
                        part: \(videoItem.part ?? "")
                        page: \(videoItem.page ?? -1)
                    """)
                task.task.resume()
            }
        }
    }

    func pauseTask(videoItem: VideoJSON.VideoData.VideoItem) {
        self.downloadingTask.forEach { (task) in
            if task.videoItem.cid! == videoItem.cid! {
                print("""
                    Pause Task \(videoItem.part ?? "")
                    """)
                task.task.suspend()
            }
        }
    }
    
    func cancelTaskInQueue(_ queue:[VideoDownloadTask], videoItem: VideoJSON.VideoData.VideoItem) {
        queue.forEach { (task) in
            if task.videoItem.cid! == videoItem.cid! {
                print("""
                    Cancel Task \(videoItem.part ?? "")
                    """)
                task.task.cancel()
            }
        }
    }
    
    func cancelTask(videoItem: VideoJSON.VideoData.VideoItem) {
        self.cancelTaskInQueue(self.downloadingTask, videoItem: videoItem)
        self.cancelTaskInQueue(self.waitingTask, videoItem: videoItem)
    }
    
    // MARK: - Download Delegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("\(downloadTask) Download Finished, local at \(location.absoluteString)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("\(downloadTask) Write \(bytesWritten) Bytes")
    }
    
}

let kTestAVNumber = 48323686

let downloader = VideoDownloader()
downloader.maxConcurrentOperationCount = 2
let connector = Connector(kTestAVNumber)
connector.connect { (json, err) in
    guard json != nil,
        err == nil,
        json!.data != nil,
        json!.data!.pages != nil else {
        return
    }
    
    // create down load task
    print("""
Start Download Video av\(kTestAVNumber)
    Title: \(json!.data!.title ?? "")
""")
    
    let items = json!.data!.pages!
    for item in items {
        downloader.addDownloadTask(videoItem: item, quality: .q480P)
    }
    
    
}



