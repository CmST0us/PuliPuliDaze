import Foundation

public struct VideoListJSON: Codable {
    public struct VideoDownloadURL : Codable {
        public var url: String?
    }
    public var durl: [VideoDownloadURL]?
}

public struct VideoJSON : Codable {
    
    public struct VideoData : Codable{
        
        public struct VideoItem : Codable {
            public var cid: Int?
            public var part: String?
            public var page: Int?
        }
        
        public var pages: [VideoItem]?
        public var title: String?
        public var aid: Int?
    }
    
    public var data: VideoData?
}

public enum VideoQuality : Int {
    case q1080PP = 112
    case q1080P = 80
    case q720P = 64
    case q480P = 32
    case q360P = 15
}
