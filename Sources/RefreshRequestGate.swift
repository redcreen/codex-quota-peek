import Foundation

struct RefreshRequestGate {
    private(set) var latestIssuedID: Int = 0

    mutating func issue() -> Int {
        latestIssuedID += 1
        return latestIssuedID
    }

    func shouldApply(_ requestID: Int) -> Bool {
        requestID == latestIssuedID
    }
}
