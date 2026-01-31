import Testing
import Foundation
@testable import DICOMWeb

@Suite("QIDO Result Tests")
struct QIDOResultTests {
    
    @Test("QIDOStudyResult initialization")
    func testStudyResult() {
        let result = QIDOStudyResult(
            studyInstanceUID: "1.2.3.4.5",
            studyDate: "20240115",
            studyTime: "143000",
            studyDescription: "CT Chest",
            accessionNumber: "ACC001",
            patientName: "Doe^John",
            patientID: "P001",
            patientBirthDate: "19800101",
            patientSex: "M",
            referringPhysicianName: "Smith^Jane",
            modalitiesInStudy: ["CT"],
            numberOfStudyRelatedSeries: 3,
            numberOfStudyRelatedInstances: 150
        )
        
        #expect(result.studyInstanceUID == "1.2.3.4.5")
        #expect(result.studyDate == "20240115")
        #expect(result.studyDescription == "CT Chest")
        #expect(result.patientName == "Doe^John")
        #expect(result.modalitiesInStudy == ["CT"])
        #expect(result.numberOfStudyRelatedSeries == 3)
    }
    
    @Test("QIDOSeriesResult initialization")
    func testSeriesResult() {
        let result = QIDOSeriesResult(
            seriesInstanceUID: "1.2.3.4.5.6",
            studyInstanceUID: "1.2.3.4.5",
            seriesNumber: 1,
            seriesDescription: "Axial Images",
            modality: "CT",
            bodyPartExamined: "CHEST",
            numberOfSeriesRelatedInstances: 50,
            performedProcedureStepStartDate: "20240115",
            performedProcedureStepStartTime: "143000"
        )
        
        #expect(result.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(result.studyInstanceUID == "1.2.3.4.5")
        #expect(result.seriesNumber == 1)
        #expect(result.modality == "CT")
        #expect(result.numberOfSeriesRelatedInstances == 50)
    }
    
    @Test("QIDOInstanceResult initialization")
    func testInstanceResult() {
        let result = QIDOInstanceResult(
            sopInstanceUID: "1.2.3.4.5.6.7",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.4.5.6",
            studyInstanceUID: "1.2.3.4.5",
            instanceNumber: 1,
            rows: 512,
            columns: 512,
            bitsAllocated: 16,
            numberOfFrames: 1
        )
        
        #expect(result.sopInstanceUID == "1.2.3.4.5.6.7")
        #expect(result.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(result.instanceNumber == 1)
        #expect(result.rows == 512)
        #expect(result.columns == 512)
    }
    
    @Test("QIDOStudyResult equality")
    func testStudyResultEquality() {
        let result1 = QIDOStudyResult(studyInstanceUID: "1.2.3")
        let result2 = QIDOStudyResult(studyInstanceUID: "1.2.3")
        let result3 = QIDOStudyResult(studyInstanceUID: "4.5.6")
        
        #expect(result1 == result2)
        #expect(result1 != result3)
    }
    
    @Test("QIDOSeriesResult equality")
    func testSeriesResultEquality() {
        let result1 = QIDOSeriesResult(seriesInstanceUID: "1.2.3", studyInstanceUID: "4.5.6")
        let result2 = QIDOSeriesResult(seriesInstanceUID: "1.2.3", studyInstanceUID: "4.5.6")
        let result3 = QIDOSeriesResult(seriesInstanceUID: "7.8.9", studyInstanceUID: "4.5.6")
        
        #expect(result1 == result2)
        #expect(result1 != result3)
    }
    
    @Test("QIDOInstanceResult equality")
    func testInstanceResultEquality() {
        let result1 = QIDOInstanceResult(sopInstanceUID: "1.2.3", sopClassUID: "4.5.6", seriesInstanceUID: "7.8.9", studyInstanceUID: "10.11.12")
        let result2 = QIDOInstanceResult(sopInstanceUID: "1.2.3", sopClassUID: "4.5.6", seriesInstanceUID: "7.8.9", studyInstanceUID: "10.11.12")
        let result3 = QIDOInstanceResult(sopInstanceUID: "99.99.99", sopClassUID: "4.5.6", seriesInstanceUID: "7.8.9", studyInstanceUID: "10.11.12")
        
        #expect(result1 == result2)
        #expect(result1 != result3)
    }
}
