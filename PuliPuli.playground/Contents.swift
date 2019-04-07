import Cocoa
import CommonCrypto

Env.checkAndCreateDownloadDocument()

let downloadAVNumber = 37669504
let downloader = VideoDownloader()
downloader.maxConcurrentOperationCount = 1

let videoInfo = VideoInfo(av: downloadAVNumber)
let (ret, _) = videoInfo.fetchInfo()
if (ret) {
    print("Ready to download \(videoInfo.title)")
    videoInfo.pagesTitle.enumerated().forEach { (i) in
        print("     \(i.offset): \(i.element)")
    }
}

let downloadPageIndex = 0...610
print("Select page \(downloadPageIndex)")

for index in downloadPageIndex {
    let page = VideoPageInfo(videoItem: videoInfo.videoPages[index])
    page.fetchDownloadURL(quality: .q480P)
    
    downloader.addTask(url: page.downloadURL[0], videoItem: page.videoItem)
    downloader.resumeTask(videoItem: page.videoItem)
}


