import Foundation

public class VideoPageInfo {
    
    public var downloadURL: [URL] = []
    
    public var videoItem: VideoJSON.VideoData.VideoItem {
        return _videoItem
    }
    
    var _videoItem: VideoJSON.VideoData.VideoItem
    var quality: VideoQuality = .q480P
    
    var downloadParam: String {
        return "appkey=\(Env.APPKey)&cid=\(videoItem.cid ?? 0)&otype=json&qn=\(quality.rawValue)&quality=\(quality.rawValue)&type="
    }
    
    var refererURL: String {
        return Env.APIBase + "/?p=\(videoItem.page ?? 0)"
    }
    
    var checkSum: String {
        return (self.downloadParam + Env.Sec).md5
    }
    
    var downloadListRequestURL: String {
        return "https://interface.bilibili.com/v2/playurl?\(downloadParam)&sign=\(checkSum)"
    }
    
    lazy var downloadRequest: URLRequest = {
        var r = URLRequest(url: URL(string: self.downloadListRequestURL)!)
        r.setValue(self.refererURL, forHTTPHeaderField: "Referer")
        r.setValue(Env.UserAgent, forHTTPHeaderField: "User-Agent")
        return r
    }()
    
    public init(videoItem: VideoJSON.VideoData.VideoItem) {
        self._videoItem = videoItem
    }
    
    public func fetchDownloadURL(quality: VideoQuality) -> (Bool, Error?){
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
