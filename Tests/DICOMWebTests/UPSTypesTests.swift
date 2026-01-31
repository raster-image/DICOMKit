import Testing
import Foundation
@testable import DICOMWeb

@Suite("UPS Types Tests")
struct UPSTypesTests {
    
    @Test("UPSWorkitem initialization")
    func testWorkitemInit() {
        let workitem = UPSWorkitem(
            workitemUID: "1.2.3.4.5",
            status: .scheduled,
            procedureStepLabel: "CT Review",
            worklistLabel: "Radiology",
            scheduledProcedureStepPriority: .high,
            scheduledStationName: "WORKSTATION1",
            patientName: "Doe^John",
            patientID: "P001"
        )
        
        #expect(workitem.workitemUID == "1.2.3.4.5")
        #expect(workitem.status == .scheduled)
        #expect(workitem.procedureStepLabel == "CT Review")
        #expect(workitem.worklistLabel == "Radiology")
        #expect(workitem.scheduledProcedureStepPriority == .high)
        #expect(workitem.scheduledStationName == "WORKSTATION1")
        #expect(workitem.patientName == "Doe^John")
        #expect(workitem.patientID == "P001")
    }
    
    @Test("UPSWorkitem default status")
    func testWorkitemDefaultStatus() {
        let workitem = UPSWorkitem()
        #expect(workitem.status == .scheduled)
    }
    
    @Test("UPSStatus values")
    func testStatusValues() {
        #expect(UPSStatus.scheduled.rawValue == "SCHEDULED")
        #expect(UPSStatus.inProgress.rawValue == "IN PROGRESS")
        #expect(UPSStatus.completed.rawValue == "COMPLETED")
        #expect(UPSStatus.canceled.rawValue == "CANCELED")
    }
    
    @Test("UPSPriority values")
    func testPriorityValues() {
        #expect(UPSPriority.low.rawValue == "LOW")
        #expect(UPSPriority.medium.rawValue == "MEDIUM")
        #expect(UPSPriority.high.rawValue == "HIGH")
    }
    
    @Test("UPSWorkitem equality")
    func testWorkitemEquality() {
        let workitem1 = UPSWorkitem(workitemUID: "1.2.3", status: .scheduled)
        let workitem2 = UPSWorkitem(workitemUID: "1.2.3", status: .scheduled)
        let workitem3 = UPSWorkitem(workitemUID: "4.5.6", status: .scheduled)
        
        #expect(workitem1 == workitem2)
        #expect(workitem1 != workitem3)
    }
    
    @Test("UPSStatus from raw value")
    func testStatusFromRawValue() {
        #expect(UPSStatus(rawValue: "SCHEDULED") == .scheduled)
        #expect(UPSStatus(rawValue: "IN PROGRESS") == .inProgress)
        #expect(UPSStatus(rawValue: "COMPLETED") == .completed)
        #expect(UPSStatus(rawValue: "CANCELED") == .canceled)
        #expect(UPSStatus(rawValue: "INVALID") == nil)
    }
    
    @Test("UPSPriority from raw value")
    func testPriorityFromRawValue() {
        #expect(UPSPriority(rawValue: "LOW") == .low)
        #expect(UPSPriority(rawValue: "MEDIUM") == .medium)
        #expect(UPSPriority(rawValue: "HIGH") == .high)
        #expect(UPSPriority(rawValue: "INVALID") == nil)
    }
}
