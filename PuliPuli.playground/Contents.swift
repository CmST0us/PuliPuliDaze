import Cocoa
import CommonCrypto

Env.checkAndCreateDownloadDocument()

let pulipuli = PuliPuliDownloader(av: 47896059)
pulipuli.fetchVideoInfo()
var s: [(Int, VideoQuality)] = []
for i in 0...1 {
    s.append((i, .q480P))
}

pulipuli.maxConcurrentOperationCount = 1
pulipuli.downloadItem = s
pulipuli.work()



