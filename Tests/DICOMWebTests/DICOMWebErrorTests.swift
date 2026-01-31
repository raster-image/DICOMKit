import Testing
import Foundation
@testable import DICOMWeb

@Suite("DICOMWeb Error Tests")
struct DICOMWebErrorTests {
    
    @Test("HTTP status code mapping - 400 Bad Request")
    func testBadRequest() {
        let error = DICOMWebError.fromHTTPStatus(400, message: "Invalid parameters")
        if case .badRequest(let message) = error {
            #expect(message == "Invalid parameters")
        } else {
            Issue.record("Expected badRequest error")
        }
    }
    
    @Test("HTTP status code mapping - 401 Unauthorized")
    func testUnauthorized() {
        let error = DICOMWebError.fromHTTPStatus(401)
        #expect(error == .unauthorized)
    }
    
    @Test("HTTP status code mapping - 403 Forbidden")
    func testForbidden() {
        let error = DICOMWebError.fromHTTPStatus(403)
        #expect(error == .forbidden)
    }
    
    @Test("HTTP status code mapping - 404 Not Found")
    func testNotFound() {
        let error = DICOMWebError.fromHTTPStatus(404)
        #expect(error == .notFound)
    }
    
    @Test("HTTP status code mapping - 409 Conflict")
    func testConflict() {
        let error = DICOMWebError.fromHTTPStatus(409, message: "Resource conflict")
        if case .conflict(let message) = error {
            #expect(message == "Resource conflict")
        } else {
            Issue.record("Expected conflict error")
        }
    }
    
    @Test("HTTP status code mapping - 503 Service Unavailable")
    func testServiceUnavailable() {
        let error = DICOMWebError.fromHTTPStatus(503)
        #expect(error == .serviceUnavailable)
    }
    
    @Test("HTTP status code mapping - unknown status")
    func testUnknownStatus() {
        let error = DICOMWebError.fromHTTPStatus(418, message: "I'm a teapot")
        if case .httpError(let statusCode, let message) = error {
            #expect(statusCode == 418)
            #expect(message == "I'm a teapot")
        } else {
            Issue.record("Expected httpError")
        }
    }
    
    @Test("Error description")
    func testErrorDescription() {
        let error = DICOMWebError.notFound
        #expect(error.errorDescription == "Resource not found")
    }
    
    @Test("Store partial failure error")
    func testStorePartialFailure() {
        let error = DICOMWebError.storePartialFailure(stored: 5, failed: 2)
        if case .storePartialFailure(let stored, let failed) = error {
            #expect(stored == 5)
            #expect(failed == 2)
        } else {
            Issue.record("Expected storePartialFailure error")
        }
    }
    
    @Test("Invalid state transition error")
    func testInvalidStateTransition() {
        let error = DICOMWebError.invalidStateTransition(from: "SCHEDULED", to: "COMPLETED")
        if case .invalidStateTransition(let from, let to) = error {
            #expect(from == "SCHEDULED")
            #expect(to == "COMPLETED")
        } else {
            Issue.record("Expected invalidStateTransition error")
        }
    }
}
