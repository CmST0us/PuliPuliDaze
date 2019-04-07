import Foundation

public class VideoInfo {
    var info: VideoJSON.VideoData!
    public var videoPages: [VideoJSON.VideoData.VideoItem] = []
    var avNumber: Int
    
    public var title: String {
        return info.title!
    }
    
    public init(av: Int) {
        self.avNumber = av
    }
    
    public func fetchInfo() -> (Bool, Error?) {
        var request = URLRequest(url: URL(string: Env.APIBase + "\(self.avNumber)")!)
        request.addValue(Env.UserAgent, forHTTPHeaderField: "User-Agent")
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
    
    public var pagesTitle: [String] {
        return self.videoPages.map({ (item) -> String in
            return item.part!
        })
    }
    
}
