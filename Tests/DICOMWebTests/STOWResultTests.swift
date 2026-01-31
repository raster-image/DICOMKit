import Testing
import Foundation
@testable import DICOMWeb

@Suite("STOW Result Tests")
struct STOWResultTests {
    
    @Test("STOWResult success")
    func testSuccess() {
        let result = STOWResult(
            successfulInstances: [
                STOWInstanceResult(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6", retrieveURL: "http://example.com/retrieve")
            ],
            failedInstances: [],
            warnings: []
        )
        
        #expect(result.isSuccess == true)
        #expect(result.hasPartialFailure == false)
        #expect(result.successfulInstances.count == 1)
    }
    
    @Test("STOWResult all failed")
    func testAllFailed() {
        let result = STOWResult(
            successfulInstances: [],
            failedInstances: [
                STOWFailedInstance(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6", failureReason: 0x0110)
            ],
            warnings: []
        )
        
        #expect(result.isSuccess == false)
        #expect(result.hasPartialFailure == false)
    }
    
    @Test("STOWResult partial failure")
    func testPartialFailure() {
        let result = STOWResult(
            successfulInstances: [
                STOWInstanceResult(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
            ],
            failedInstances: [
                STOWFailedInstance(sopClassUID: "1.2.3", sopInstanceUID: "7.8.9", failureReason: 0x0110)
            ],
            warnings: ["Some warning"]
        )
        
        #expect(result.isSuccess == false)
        #expect(result.hasPartialFailure == true)
        #expect(result.warnings.count == 1)
    }
    
    @Test("STOWInstanceResult initialization")
    func testInstanceResult() {
        let result = STOWInstanceResult(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.7",
            sopInstanceUID: "1.2.3.4.5.6.7",
            retrieveURL: "http://pacs.hospital.com/dicomweb/studies/1.2.3/instances/1.2.3.4.5.6.7"
        )
        
        #expect(result.sopClassUID == "1.2.840.10008.5.1.4.1.1.7")
        #expect(result.sopInstanceUID == "1.2.3.4.5.6.7")
        #expect(result.retrieveURL?.contains("dicomweb") == true)
    }
    
    @Test("STOWFailedInstance with processing failure")
    func testFailedInstanceProcessingFailure() {
        let result = STOWFailedInstance(
            sopClassUID: "1.2.3",
            sopInstanceUID: "4.5.6",
            failureReason: 0x0110
        )
        
        #expect(result.failureReasonDescription == "Processing failure")
    }
    
    @Test("STOWFailedInstance with duplicate SOP instance")
    func testFailedInstanceDuplicate() {
        let result = STOWFailedInstance(
            sopClassUID: "1.2.3",
            sopInstanceUID: "4.5.6",
            failureReason: 0x0111
        )
        
        #expect(result.failureReasonDescription == "Duplicate SOP instance")
    }
    
    @Test("STOWFailedInstance with out of resources")
    func testFailedInstanceOutOfResources() {
        let result = STOWFailedInstance(
            sopClassUID: "1.2.3",
            sopInstanceUID: "4.5.6",
            failureReason: 0xA700
        )
        
        #expect(result.failureReasonDescription == "Out of resources")
    }
    
    @Test("STOWFailedInstance with unknown failure")
    func testFailedInstanceUnknown() {
        let result = STOWFailedInstance(
            sopClassUID: "1.2.3",
            sopInstanceUID: "4.5.6",
            failureReason: 0xFFFF
        )
        
        #expect(result.failureReasonDescription.contains("Unknown"))
    }
    
    @Test("STOWResult equality")
    func testResultEquality() {
        let result1 = STOWResult(
            successfulInstances: [STOWInstanceResult(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")],
            failedInstances: [],
            warnings: []
        )
        let result2 = STOWResult(
            successfulInstances: [STOWInstanceResult(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")],
            failedInstances: [],
            warnings: []
        )
        
        #expect(result1 == result2)
    }
    
    @Test("STOWFailureReason descriptions")
    func testFailureReasonDescriptions() {
        #expect(STOWFailureReason.processingFailure.description == "Processing failure")
        #expect(STOWFailureReason.duplicateSOPInstance.description == "Duplicate SOP instance")
        #expect(STOWFailureReason.noSuchAttribute.description == "No such attribute")
        #expect(STOWFailureReason.invalidAttributeValue.description == "Invalid attribute value")
        #expect(STOWFailureReason.missingAttribute.description == "Missing attribute")
        #expect(STOWFailureReason.missingAttributeValue.description == "Missing attribute value")
        #expect(STOWFailureReason.outOfResources.description == "Out of resources")
        #expect(STOWFailureReason.dataSetDoesNotMatchSOPClass.description == "Data set does not match SOP class")
        #expect(STOWFailureReason.cannotUnderstand.description == "Cannot understand")
    }
}
