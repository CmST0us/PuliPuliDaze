import Cocoa
import CommonCrypto

Env.checkAndCreateDownloadDocument()

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


