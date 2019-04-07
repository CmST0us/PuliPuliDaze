import Foundation

public class Env {
    public static let UserAgent = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"
    public static let APIBase = "https://api.bilibili.com/x/web-interface/view?aid="
    public static let APPKey = "iVGUTjsxvpLeuDCf"
    public static let Sec = "aHRmhWMLkdeMuILqORnYZocwMBpMEOdt"
    
    public static var defaultDownloadPath: String {
        return NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)[0] + "/PuliPuli"
    }
    
    public static var downloadPath: String {
        get {
            return UserDefaults.standard.string(forKey: "downloadPath") ?? self.defaultDownloadPath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "downloadPath")
        }
    }
    
    public static func checkAndCreateDownloadDocument() {
        if FileManager.default.fileExists(atPath: self.downloadPath) {
            return
        }
        try? FileManager.default.createDirectory(atPath: self.downloadPath, withIntermediateDirectories: true, attributes: nil)
    }
}
