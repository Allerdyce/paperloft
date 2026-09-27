import Foundation
import os
let log = OSLog(subsystem: "app.paperloft.signpostprobe", category: "Pipeline")
Thread.sleep(forTimeInterval: 1)
for _ in 0..<5 {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "Probe", signpostID: id)
    Thread.sleep(forTimeInterval: 0.1)
    os_signpost(.end, log: log, name: "Probe", signpostID: id)
    Thread.sleep(forTimeInterval: 0.1)
}
Thread.sleep(forTimeInterval: 1)
