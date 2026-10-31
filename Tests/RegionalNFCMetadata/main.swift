import Foundation
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let legacy = try decoder.decode(RegionalCardCapture.self, from: Data("{\"formatVersion\":6,\"date\":\"2026-10-19T12:00:00Z\",\"requestedNetwork\":\"test\",\"status\":\"test\",\"selectedApplication\":\"test\",\"exchanges\":[]}".utf8))
precondition(legacy.nfcMetadata == nil)
var capture = legacy
capture.nfcMetadata = .init(identifier: "test", initialSelectedAID: "test", historicalBytes: nil, applicationData: "12345678", proprietaryApplicationDataCoding: false)
precondition(capture.nfcMetadata!.observedProtocol == "ISO 14443 Type B observé")
let restored = try decoder.decode(RegionalCardCapture.self, from: Data(capture.json.utf8))
precondition(restored.nfcMetadata?.applicationData == "12345678")
capture.nfcMetadata = .init(identifier: "test", initialSelectedAID: "test", historicalBytes: "01", applicationData: nil, proprietaryApplicationDataCoding: false)
precondition(capture.nfcMetadata!.observedProtocol == "ISO 14443 Type A observé")
print("NFC metadata: legacy report compatibility, persistence and observed-interface labels passed")
