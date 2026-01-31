/// DICOMWeb - DICOM Web Services Support
///
/// This module provides RESTful DICOM web services (DICOMweb) capabilities for DICOMKit,
/// implementing client support for WADO-RS, STOW-RS, QIDO-RS, and UPS-RS.
///
/// Reference: DICOM PS3.18 - Web Services
///
/// ## Overview
///
/// DICOMWeb provides types and protocols for RESTful DICOM web communication,
/// enabling access to DICOM objects over HTTP/HTTPS without requiring traditional
/// DICOM network protocols.
///
/// ## Key Features
///
/// - **WADO-RS** (Web Access to DICOM Objects - RESTful Services)
///   - Retrieve DICOM instances by study/series/instance UIDs
///   - Retrieve bulk data (pixel data)
///   - Retrieve metadata as JSON
///   - Support for multipart responses
///
/// - **STOW-RS** (Store Over the Web - RESTful Services)
///   - Store DICOM instances via HTTP POST
///   - Multipart request encoding
///   - Response parsing for stored instances
///
/// - **QIDO-RS** (Query based on ID for DICOM Objects - RESTful)
///   - Search for studies matching criteria
///   - Search for series within studies
///   - Search for instances within series
///   - JSON response parsing
///
/// - **UPS-RS** (Unified Procedure Step - RESTful Services)
///   - Create workitems
///   - Update workitem state
///   - Subscribe to workitem events
///
/// ## Usage
///
/// ### Basic Configuration
///
/// ```swift
/// import DICOMWeb
///
/// // Create a DICOMweb client
/// let client = DICOMWebClient(
///     baseURL: URL(string: "https://pacs.hospital.com/dicomweb")!,
///     authentication: .bearer(token: "your-token")
/// )
/// ```
///
/// ### WADO-RS - Retrieving Studies
///
/// ```swift
/// // Retrieve all instances in a study
/// let instances = try await client.wado.retrieveStudy(
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// // Retrieve metadata only
/// let metadata = try await client.wado.retrieveStudyMetadata(
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// // Retrieve a specific instance
/// let instance = try await client.wado.retrieveInstance(
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9",
///     seriesInstanceUID: "1.2.3.4.5.6.7.8.9.10",
///     sopInstanceUID: "1.2.3.4.5.6.7.8.9.10.11"
/// )
/// ```
///
/// ### QIDO-RS - Querying
///
/// ```swift
/// // Search for studies
/// let studies = try await client.qido.searchStudies(
///     patientName: "DOE^JOHN*",
///     studyDate: "20240101-20241231",
///     modality: "CT"
/// )
///
/// // Search for series in a study
/// let series = try await client.qido.searchSeries(
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9",
///     modality: "CT"
/// )
/// ```
///
/// ### STOW-RS - Storing Instances
///
/// ```swift
/// // Store DICOM instances
/// let result = try await client.stow.store(
///     instances: [dicomData1, dicomData2],
///     studyInstanceUID: "1.2.3.4.5.6.7.8.9"
/// )
///
/// print("Stored: \(result.successfulInstances.count)")
/// print("Failed: \(result.failedInstances.count)")
/// ```
///
/// ### UPS-RS - Unified Procedure Step
///
/// ```swift
/// // Create a workitem
/// let workitem = try await client.ups.createWorkitem(
///     workitem: UPSWorkitem(
///         procedureStepLabel: "CT Scan Review",
///         scheduledStationName: "REVIEW_WS_1"
///     )
/// )
///
/// // Subscribe to workitem changes
/// for try await event in client.ups.subscribe(workitemUID: workitem.uid) {
///     print("Workitem state: \(event.state)")
/// }
/// ```

@_exported import Foundation
@_exported import DICOMCore

// Re-export all public types from this module
