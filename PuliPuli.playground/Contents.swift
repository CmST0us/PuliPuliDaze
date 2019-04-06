import Cocoa
import CommonCrypto

let kUserAgent = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"
let kAPIBase = "https://api.bilibili.com/x/web-interface/view?aid="
let kAPPKey = "iVGUTjsxvpLeuDCf"
let kSec = "aHRmhWMLkdeMuILqORnYZocwMBpMEOdt"

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
    case q1080P = 80
    case q720P = 64
    case q480P = 32
    case q360P = 15
}

class VideoDownloadTask: Operation {
    var videoItem: VideoJSON.VideoData.VideoItem!
    var quality: VideoQuality = .q360P
    
    var videoPageURL: String {
        if (self.videoItem == nil) {
            return ""
        }
        return kAPIBase + "/?p=\(videoItem.page ?? 0)"
    }
    
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
    
    override func main() {
        let (data, _, _) = URLSession.shared.syncDataTask(request: self.downloadRequest)
        guard data != nil else {
            return
        }
        
        let str = String(data: data!, encoding: .utf8)
        str
    }
}

class VideoDownloader {
    private var downloadOperation: OperationQueue
    var maxConcurrentOperationCount: Int = 1 {
        didSet {
            downloadOperation.maxConcurrentOperationCount = self.maxConcurrentOperationCount
        }
    }
    
    init() {
        downloadOperation = OperationQueue()
    }
    
    func addDownloadTask(videoItem: VideoJSON.VideoData.VideoItem, quality: VideoQuality) {
        
        let task = VideoDownloadTask()
        task.videoItem = videoItem
        task.quality = quality
        
        downloadOperation.addOperation(task)
        
        print("""
            Create Task:
                cid: \(videoItem.cid ?? -1)
                part: \(videoItem.part ?? "")
                page: \(videoItem.page ?? -1)
            """)
        
    }
    
}

let kTestAVNumber = 37669504

let downloader = VideoDownloader()
downloader.maxConcurrentOperationCount = 1
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



