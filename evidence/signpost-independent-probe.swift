import XCTest
import os
final class SignpostProbe: XCTestCase {
    func testPairedIntervals() {
        let custom = OSLog(subsystem: "app.paperloft.probe", category: "Custom")
        let interest = OSLog(subsystem: "app.paperloft.probe", category: .pointsOfInterest)
        let options = XCTMeasureOptions(); options.iterationCount = 1
        measure(metrics: [XCTClockMetric(), XCTOSSignpostMetric(subsystem: "app.paperloft.probe", category: "Custom", name: "Probe"), XCTOSSignpostMetric(subsystem: "app.paperloft.probe", category: "PointsOfInterest", name: "Probe")], options: options) {
            let first = OSSignpostID(log: custom), second = OSSignpostID(log: interest)
            os_signpost(.begin, log: custom, name: "Probe", signpostID: first)
            os_signpost(.begin, log: interest, name: "Probe", signpostID: second)
            Thread.sleep(forTimeInterval: 0.01)
            os_signpost(.end, log: interest, name: "Probe", signpostID: second)
            os_signpost(.end, log: custom, name: "Probe", signpostID: first)
        }
    }
}
