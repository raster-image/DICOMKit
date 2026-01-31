# DICOMViewer Example Application - Development Plan

This document outlines a comprehensive phased development plan for creating an example DICOMViewer application using DICOMKit. The application will demonstrate the full capabilities of DICOMKit while providing a real-world reference implementation for developers.

## Overview

The DICOMViewer example application will be a cross-platform SwiftUI application supporting iOS, macOS, and visionOS. The development is **PACS-first**, meaning we prioritize network connectivity to query patient data from PACS servers before building local file viewing capabilities.

**Development Priority Order:**
1. **PACS Connectivity** - Query patient details from PACS (C-FIND)
2. **Image Retrieval** - Download images from PACS (C-GET/C-MOVE)
3. **Image Display** - Render and manipulate DICOM images
4. **Advanced Features** - Measurements, annotations, study management

This approach allows the application to be immediately useful in clinical workflows where data primarily comes from PACS systems.

### Key Features (in priority order):

1. PACS connectivity (Query/Retrieve) - **PRIMARY FOCUS**
2. Patient/Study/Series browsing from PACS
3. DICOM image retrieval and rendering
4. Image manipulation (windowing, pan, zoom)
5. Multi-frame/series navigation
6. Local file reading (secondary)
7. DICOM network operations

---

## Phase 1: PACS Connectivity - Patient Query (2-3 weeks)

**Goal**: Establish connection to PACS servers and query patient details using C-FIND.

### 1.1 Project Setup

**Deliverables:**
- [ ] Create new SwiftUI App project using Xcode
- [ ] Configure for multi-platform (iOS 17+, macOS 14+, visionOS 1.0+)
- [ ] Add DICOMKit as Swift Package dependency
- [ ] Set up project structure following MVVM architecture
- [ ] Import DICOMNetwork module for PACS connectivity

**Implementation Pointers:**
```swift
// Package.swift or Xcode project dependency
.package(url: "https://github.com/raster-image/DICOMKit.git", from: "0.7.0")

// Required imports for PACS connectivity
import DICOMKit
import DICOMCore
import DICOMNetwork
```

**Directory Structure (PACS-First Architecture):**
```
DICOMViewer/
├── App/
│   ├── DICOMViewerApp.swift
│   └── AppState.swift
├── Models/
│   ├── PACSServer.swift           // PACS server configuration
│   ├── PatientSearchCriteria.swift // Patient search parameters
│   └── QueryResultModels.swift    // Patient/Study/Series models
├── Views/
│   ├── ContentView.swift
│   ├── ServerConfigView.swift     // PACS server setup
│   ├── PatientSearchView.swift    // Patient search form
│   ├── PatientListView.swift      // Patient results
│   ├── StudyListView.swift        // Studies for patient
│   └── Components/
├── ViewModels/
│   ├── PACSConnectionViewModel.swift
│   ├── PatientSearchViewModel.swift
│   └── QueryResultsViewModel.swift
├── Services/
│   ├── PACSQueryService.swift     // Wraps DICOMQueryService
│   ├── ConnectionTestService.swift // C-ECHO verification
│   └── ServerStorageService.swift // Persist server configs
└── Resources/
```

### 1.2 PACS Server Configuration

**Deliverables:**
- [ ] Server configuration data model
- [ ] Server settings UI (host, port, AE titles)
- [ ] Save/load server configurations with UserDefaults/Keychain
- [ ] Support for multiple saved servers
- [ ] TLS configuration options

**Implementation Pointers:**
```swift
// PACS Server configuration model
struct PACSServer: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String              // Display name (e.g., "Main PACS")
    var host: String              // IP or hostname
    var port: UInt16              // Default: 104 or 11112
    var calledAETitle: String     // Remote PACS AE Title
    var callingAETitle: String    // Our local AE Title
    var useTLS: Bool = false      // Enable secure connection
    var timeout: TimeInterval = 60
    
    // Convenience initializer
    init(name: String, host: String, port: UInt16 = 104, 
         calledAE: String, callingAE: String) {
        self.name = name
        self.host = host
        self.port = port
        self.calledAETitle = calledAE
        self.callingAETitle = callingAE
    }
}

// Server configuration view
struct ServerConfigView: View {
    @State private var server = PACSServer(
        name: "New Server",
        host: "",
        calledAE: "PACS",
        callingAE: "DICOMVIEWER"
    )
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?
    
    var body: some View {
        Form {
            Section("Server Details") {
                TextField("Server Name", text: $server.name)
                TextField("Host/IP Address", text: $server.host)
                    .textContentType(.URL)
                TextField("Port", value: $server.port, format: .number)
                    .keyboardType(.numberPad)
            }
            
            Section("AE Titles") {
                TextField("Called AE (Remote PACS)", text: $server.calledAETitle)
                    .textCase(.uppercase)
                TextField("Calling AE (This App)", text: $server.callingAETitle)
                    .textCase(.uppercase)
            }
            
            Section("Security") {
                Toggle("Use TLS Encryption", isOn: $server.useTLS)
            }
            
            Section {
                Button(action: testConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                        }
                        Text("Test Connection (C-ECHO)")
                    }
                }
                .disabled(server.host.isEmpty || isTestingConnection)
                
                if let status = connectionStatus {
                    ConnectionStatusView(status: status)
                }
            }
        }
    }
    
    func testConnection() {
        isTestingConnection = true
        Task {
            do {
                let success = try await PACSQueryService.testConnection(to: server)
                await MainActor.run {
                    connectionStatus = success ? .connected : .failed("No response")
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failed(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
}

enum ConnectionStatus {
    case connected
    case failed(String)
}
```

**Key APIs:**
- `DICOMClientConfiguration` - Client connection settings
- `AETitle` - Application Entity title validation (max 16 chars, uppercase)
- `TLSConfiguration` - Secure connection settings

### 1.3 Connection Verification (C-ECHO)

**Deliverables:**
- [ ] Implement C-ECHO verification service
- [ ] Connection test button with status feedback
- [ ] Error display with recovery suggestions
- [ ] Connection timeout handling

**Implementation Pointers:**
```swift
// PACS Query Service - wraps DICOMKit networking
actor PACSQueryService {
    
    /// Tests connection to a PACS server using C-ECHO
    static func testConnection(to server: PACSServer) async throws -> Bool {
        // Build configuration
        let config = try DICOMClientConfiguration(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            timeout: server.timeout,
            tlsConfiguration: server.useTLS ? .default : nil
        )
        
        // Create client and verify
        let client = DICOMClient(configuration: config)
        let result = try await client.verify()
        
        return result.success
    }
}

// Alternative: Direct use of VerificationService
func testConnectionDirect(server: PACSServer) async throws -> VerificationResult {
    let callingAE = try AETitle(server.callingAETitle)
    let calledAE = try AETitle(server.calledAETitle)
    
    let config = VerificationConfiguration(
        callingAETitle: callingAE,
        calledAETitle: calledAE,
        timeout: server.timeout
    )
    
    return try await VerificationService.verify(
        host: server.host,
        port: server.port,
        configuration: config
    )
}
```

**Key APIs:**
- `DICOMClient.verify()` - High-level C-ECHO
- `VerificationService.verify()` - Low-level C-ECHO
- `VerificationResult` - Contains success status and response time

### 1.4 Patient Query (C-FIND) - **CORE FEATURE**

**Deliverables:**
- [ ] Patient search form with key fields
- [ ] Patient Name search with wildcard support (* and ?)
- [ ] Patient ID search
- [ ] Birth date range search
- [ ] Display patient query results
- [ ] Drill-down from patient to studies

**Implementation Pointers:**
```swift
// Patient search criteria
struct PatientSearchCriteria {
    // Supports DICOM wildcards:
    // - '*' matches zero or more characters (e.g., "SMITH*" matches "SMITH", "SMITHSON")
    // - '?' matches exactly one character (e.g., "SM?TH" matches "SMITH", "SMYTH")
    var patientName: String = ""
    var patientID: String = ""
    var patientBirthDateFrom: Date?
    var patientBirthDateTo: Date?
    var patientSex: String?  // "M", "F", "O", or nil for any
    
    /// Formats date range for DICOM query
    var birthDateRange: String? {
        guard let from = patientBirthDateFrom else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        
        if let to = patientBirthDateTo {
            return "\(formatter.string(from: from))-\(formatter.string(from: to))"
        }
        return formatter.string(from: from)
    }
}

// Patient search service
extension PACSQueryService {
    
    /// Queries patients from PACS server
    /// - Parameters:
    ///   - server: The PACS server to query
    ///   - criteria: Search criteria for patient matching
    /// - Returns: Array of matching patients
    static func findPatients(
        on server: PACSServer,
        matching criteria: PatientSearchCriteria
    ) async throws -> [PatientResult] {
        
        // Build query keys for patient-level query
        var queryKeys = QueryKeys(level: .patient)
            .requestPatientName()
            .requestPatientID()
            .requestPatientBirthDate()
            .requestPatientSex()
            .requestNumberOfPatientRelatedStudies()
            .requestNumberOfPatientRelatedSeries()
            .requestNumberOfPatientRelatedInstances()
        
        // Add matching criteria
        if !criteria.patientName.isEmpty {
            queryKeys = queryKeys.patientName(criteria.patientName)
        }
        if !criteria.patientID.isEmpty {
            queryKeys = queryKeys.patientID(criteria.patientID)
        }
        if let birthDateRange = criteria.birthDateRange {
            queryKeys = queryKeys.patientBirthDate(birthDateRange)
        }
        if let sex = criteria.patientSex {
            queryKeys = queryKeys.patientSex(sex)
        }
        
        // Create configuration for Patient Root Information Model
        let callingAE = try AETitle(server.callingAETitle)
        let calledAE = try AETitle(server.calledAETitle)
        
        let config = QueryConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: server.timeout,
            informationModel: .patientRoot  // Use Patient Root for patient queries
        )
        
        // Perform the query
        let results = try await DICOMQueryService.find(
            host: server.host,
            port: server.port,
            configuration: config,
            queryKeys: queryKeys
        )
        
        return results.map { $0.toPatientResult() }
    }
}

// Patient result display model
struct PatientDisplayModel: Identifiable {
    let id: String  // Patient ID
    let name: String
    let birthDate: String?
    let sex: String?
    let studyCount: Int?
    
    init(from result: PatientResult) {
        self.id = result.patientID ?? UUID().uuidString
        self.name = result.patientName ?? "Unknown"
        self.birthDate = result.patientBirthDate
        self.sex = result.patientSex
        self.studyCount = result.numberOfPatientRelatedStudies
    }
    
    /// Formats the birth date for display
    var formattedBirthDate: String {
        guard let dateStr = birthDate, dateStr.count == 8 else {
            return "Unknown"
        }
        // Convert YYYYMMDD to readable format
        let year = dateStr.prefix(4)
        let month = dateStr.dropFirst(4).prefix(2)
        let day = dateStr.dropFirst(6).prefix(2)
        return "\(month)/\(day)/\(year)"
    }
}
```

**Patient Search UI:**
```swift
struct PatientSearchView: View {
    @State private var criteria = PatientSearchCriteria()
    @State private var results: [PatientDisplayModel] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    let server: PACSServer
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Form
                Form {
                    Section("Search Criteria") {
                        TextField("Patient Name (use * for wildcard)", 
                                  text: $criteria.patientName)
                            .autocapitalization(.allCharacters)
                        
                        TextField("Patient ID", text: $criteria.patientID)
                        
                        DatePicker("Birth Date From", 
                                   selection: Binding(
                                       get: { criteria.patientBirthDateFrom ?? Date() },
                                       set: { criteria.patientBirthDateFrom = $0 }
                                   ),
                                   displayedComponents: .date)
                        
                        Picker("Sex", selection: $criteria.patientSex) {
                            Text("Any").tag(nil as String?)
                            Text("Male").tag("M" as String?)
                            Text("Female").tag("F" as String?)
                            Text("Other").tag("O" as String?)
                        }
                    }
                    
                    Section {
                        Button(action: performSearch) {
                            HStack {
                                if isSearching {
                                    ProgressView()
                                }
                                Text("Search Patients")
                            }
                        }
                        .disabled(isSearching)
                    }
                }
                .frame(maxHeight: 300)
                
                // Results
                if let error = errorMessage {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Enter search criteria and tap Search")
                    )
                } else {
                    PatientResultsListView(patients: results, server: server)
                }
            }
            .navigationTitle("Patient Search")
        }
    }
    
    func performSearch() {
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let patientResults = try await PACSQueryService.findPatients(
                    on: server,
                    matching: criteria
                )
                
                await MainActor.run {
                    results = patientResults.map { PatientDisplayModel(from: $0) }
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

// Patient results list
struct PatientResultsListView: View {
    let patients: [PatientDisplayModel]
    let server: PACSServer
    
    var body: some View {
        List(patients) { patient in
            NavigationLink(destination: StudyListView(
                server: server,
                patientID: patient.id,
                patientName: patient.name
            )) {
                PatientRowView(patient: patient)
            }
        }
    }
}

struct PatientRowView: View {
    let patient: PatientDisplayModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(patient.name)
                .font(.headline)
            
            HStack {
                Label(patient.id, systemImage: "person.text.rectangle")
                    .font(.subheadline)
                
                Spacer()
                
                if let sex = patient.sex {
                    Text(sex)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("DOB: \(patient.formattedBirthDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let count = patient.studyCount {
                    Text("\(count) studies")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Key APIs:**
- `QueryKeys(level: .patient)` - Create patient-level query
- `QueryKeys.patientName(_:)` - Match patient name with wildcards
- `QueryKeys.patientID(_:)` - Match patient ID
- `QueryKeys.patientBirthDate(_:)` - Match birth date or range
- `QueryKeys.requestPatientName()` - Request attribute in response
- `DICOMQueryService.find()` - Execute C-FIND query
- `PatientResult` - Type-safe patient query result

### 1.5 Study Query for Selected Patient

**Deliverables:**
- [ ] Query studies for a selected patient
- [ ] Display study list with metadata
- [ ] Study date, description, modality display
- [ ] Series count per study
- [ ] Navigate to series view

**Implementation Pointers:**
```swift
// Query studies for a patient
extension PACSQueryService {
    
    /// Queries studies for a specific patient from PACS
    static func findStudies(
        on server: PACSServer,
        forPatientID patientID: String,
        dateRange: String? = nil,
        modality: String? = nil
    ) async throws -> [StudyResult] {
        
        var queryKeys = QueryKeys(level: .study)
            .patientID(patientID)
            .requestPatientName()
            .requestPatientID()
            .requestStudyInstanceUID()
            .requestStudyDate()
            .requestStudyTime()
            .requestStudyDescription()
            .requestAccessionNumber()
            .requestModalitiesInStudy()
            .requestReferringPhysicianName()
            .requestNumberOfStudyRelatedSeries()
            .requestNumberOfStudyRelatedInstances()
        
        // Add optional filters
        if let dateRange = dateRange {
            queryKeys = queryKeys.studyDate(dateRange)
        }
        if let modality = modality {
            queryKeys = queryKeys.modalitiesInStudy(modality)
        }
        
        // Use the convenience method for study queries
        return try await DICOMQueryService.findStudies(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            matching: queryKeys,
            timeout: server.timeout
        )
    }
}

// Study list view
struct StudyListView: View {
    let server: PACSServer
    let patientID: String
    let patientName: String
    
    @State private var studies: [StudyResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading studies...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to Load Studies",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if studies.isEmpty {
                ContentUnavailableView(
                    "No Studies Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No studies found for this patient")
                )
            } else {
                List(studies, id: \.studyInstanceUID) { study in
                    NavigationLink(destination: SeriesListView(
                        server: server,
                        studyInstanceUID: study.studyInstanceUID ?? ""
                    )) {
                        StudyRowView(study: study)
                    }
                }
            }
        }
        .navigationTitle(patientName)
        .task {
            await loadStudies()
        }
    }
    
    func loadStudies() async {
        do {
            let results = try await PACSQueryService.findStudies(
                on: server,
                forPatientID: patientID
            )
            await MainActor.run {
                studies = results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct StudyRowView: View {
    let study: StudyResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(study.studyDescription ?? "No Description")
                .font(.headline)
            
            HStack {
                if let date = study.studyDate {
                    Label(formatDICOMDate(date), systemImage: "calendar")
                }
                
                Spacer()
                
                // Show modalities
                Text(study.modalitiesInStudy ?? "")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .font(.subheadline)
            
            HStack {
                if let accession = study.accessionNumber {
                    Text("Acc#: \(accession)")
                }
                
                Spacer()
                
                if let series = study.numberOfStudyRelatedSeries,
                   let instances = study.numberOfStudyRelatedInstances {
                    Text("\(series) series, \(instances) images")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    func formatDICOMDate(_ dateStr: String) -> String {
        guard dateStr.count == 8 else { return dateStr }
        let year = dateStr.prefix(4)
        let month = dateStr.dropFirst(4).prefix(2)
        let day = dateStr.dropFirst(6).prefix(2)
        return "\(month)/\(day)/\(year)"
    }
}
```

**Key APIs:**
- `DICOMQueryService.findStudies()` - Study-level C-FIND
- `StudyResult` - Type-safe study query result with accessors:
  - `.studyInstanceUID` - Unique study identifier
  - `.studyDate`, `.studyTime` - When study was performed
  - `.studyDescription` - Description text
  - `.accessionNumber` - Hospital accession number
  - `.modalitiesInStudy` - List of modalities (CT, MR, etc.)
  - `.numberOfStudyRelatedSeries` - Series count
  - `.numberOfStudyRelatedInstances` - Image count

### 1.6 Series Query for Selected Study

**Deliverables:**
- [ ] Query series for a selected study
- [ ] Display series list with modality and description
- [ ] Instance count per series
- [ ] Navigate to image retrieval

**Implementation Pointers:**
```swift
// Query series for a study
extension PACSQueryService {
    
    static func findSeries(
        on server: PACSServer,
        forStudyUID studyUID: String,
        modality: String? = nil
    ) async throws -> [SeriesResult] {
        
        var queryKeys = QueryKeys(level: .series)
        
        // Add modality filter if specified
        if let modality = modality {
            queryKeys = queryKeys.modality(modality)
        }
        
        return try await DICOMQueryService.findSeries(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            forStudy: studyUID,
            matching: queryKeys,
            timeout: server.timeout
        )
    }
}

// Series list view
struct SeriesListView: View {
    let server: PACSServer
    let studyInstanceUID: String
    
    @State private var series: [SeriesResult] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading series...")
            } else {
                List(series, id: \.seriesInstanceUID) { s in
                    SeriesRowView(series: s)
                }
            }
        }
        .navigationTitle("Series")
        .task {
            await loadSeries()
        }
    }
    
    func loadSeries() async {
        do {
            series = try await PACSQueryService.findSeries(
                on: server,
                forStudyUID: studyInstanceUID
            )
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

struct SeriesRowView: View {
    let series: SeriesResult
    
    var body: some View {
        HStack {
            // Modality badge
            Text(series.modality ?? "??")
                .font(.headline)
                .padding(8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(series.seriesDescription ?? "Series \(series.seriesNumber ?? 0)")
                    .font(.headline)
                
                if let count = series.numberOfSeriesRelatedInstances {
                    Text("\(count) images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let number = series.seriesNumber {
                Text("#\(number)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

**Key APIs:**
- `DICOMQueryService.findSeries()` - Series-level C-FIND
- `SeriesResult` - Type-safe series query result

### 1.7 Error Handling and Network Resilience

**Deliverables:**
- [ ] Categorized network error handling
- [ ] User-friendly error messages with recovery suggestions
- [ ] Retry logic for transient failures
- [ ] Timeout configuration

**Implementation Pointers:**
```swift
// Error handling
func handleQueryError(_ error: Error) -> (title: String, message: String, canRetry: Bool) {
    if let networkError = error as? DICOMNetworkError {
        switch networkError.category {
        case .transient:
            return ("Connection Issue", 
                    "Temporary network problem. Please try again.", 
                    true)
        case .timeout:
            return ("Timeout", 
                    "The server took too long to respond. Check network connection.", 
                    true)
        case .configuration:
            return ("Configuration Error", 
                    "Check AE titles and server settings.", 
                    false)
        case .permanent:
            return ("Server Error", 
                    networkError.localizedDescription, 
                    false)
        case .protocol:
            return ("Protocol Error", 
                    "DICOM communication error. Contact support.", 
                    false)
        case .resource:
            return ("Resource Error", 
                    "Server resources unavailable.", 
                    true)
        }
    }
    
    return ("Error", error.localizedDescription, true)
}

// Retry configuration
let retryPolicy = RetryPolicy.exponentialBackoff(
    maxRetries: 3,
    baseDelay: .seconds(1),
    maxDelay: .seconds(10)
)
```

### Phase 1 Acceptance Criteria

- [ ] Can configure and save PACS server connections
- [ ] C-ECHO verification works and shows connection status
- [ ] Patient search with wildcards returns matching patients
- [ ] Patient details (name, ID, DOB, sex) display correctly
- [ ] Can drill down from patient → studies → series
- [ ] Error messages are user-friendly with recovery suggestions
- [ ] Works on iOS, macOS, and visionOS
- [ ] Network timeouts are handled gracefully

---

## Phase 2: Image Retrieval from PACS (2-3 weeks)

**Goal**: Download DICOM images from PACS using C-GET or C-MOVE and render them for display.

### 2.1 C-GET Image Retrieval (Recommended for Client Apps)

**Deliverables:**
- [ ] Implement C-GET to retrieve images on same association
- [ ] Progress display during download
- [ ] Parse received DICOM data
- [ ] Store retrieved images locally
- [ ] Handle multi-frame and multi-instance series

**Implementation Pointers:**
```swift
// Retrieve series images using C-GET
extension PACSQueryService {
    
    /// Retrieves all images for a series using C-GET
    /// C-GET is preferred for client apps as it doesn't require a separate SCP
    static func retrieveSeries(
        from server: PACSServer,
        studyUID: String,
        seriesUID: String,
        onProgress: @escaping (RetrieveProgress) -> Void,
        onImageReceived: @escaping (Data) -> Void
    ) async throws -> RetrieveResult {
        
        let config = try DICOMClientConfiguration(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            timeout: server.timeout * 4  // Longer timeout for retrieval
        )
        
        let client = DICOMClient(configuration: config)
        
        // Use C-GET to retrieve series
        let progressStream = try await client.getSeries(
            studyInstanceUID: studyUID,
            seriesInstanceUID: seriesUID,
            priority: .medium
        )
        
        var finalResult: RetrieveResult?
        
        // Process the async stream of events
        for try await event in progressStream {
            switch event {
            case .progress(let progress):
                await MainActor.run {
                    onProgress(progress)
                }
                
            case .instanceReceived(let data):
                await MainActor.run {
                    onImageReceived(data)
                }
                
            case .completed(let result):
                finalResult = result
                
            case .error(let error):
                throw error
            }
        }
        
        guard let result = finalResult else {
            throw DICOMNetworkError.invalidState("Retrieval completed without result")
        }
        
        return result
    }
}

// Retrieve view model
@Observable
class RetrieveViewModel {
    var isRetrieving = false
    var progress: RetrieveProgress?
    var retrievedImages: [DICOMFile] = []
    var errorMessage: String?
    
    func retrieveSeries(server: PACSServer, studyUID: String, seriesUID: String) {
        isRetrieving = true
        errorMessage = nil
        retrievedImages = []
        
        Task {
            do {
                let result = try await PACSQueryService.retrieveSeries(
                    from: server,
                    studyUID: studyUID,
                    seriesUID: seriesUID,
                    onProgress: { [weak self] progress in
                        self?.progress = progress
                    },
                    onImageReceived: { [weak self] data in
                        if let dicomFile = try? DICOMFile.read(from: data) {
                            self?.retrievedImages.append(dicomFile)
                        }
                    }
                )
                
                await MainActor.run {
                    isRetrieving = false
                    print("Retrieved \(result.completed) images")
                }
            } catch {
                await MainActor.run {
                    isRetrieving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

**Key APIs:**
- `DICOMClient.getSeries()` - C-GET series retrieval
- `DICOMClient.getStudy()` - C-GET entire study
- `DICOMClient.getInstance()` - C-GET single instance
- `RetrieveProgress` - Progress tracking (completed, remaining, failed)
- `RetrieveResult` - Final retrieval status

### 2.2 Retrieve Progress UI

**Deliverables:**
- [ ] Download progress bar
- [ ] Image count display
- [ ] Cancel retrieve operation
- [ ] Error handling for failed images

**Implementation Pointers:**
```swift
struct RetrieveProgressView: View {
    @Bindable var viewModel: RetrieveViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isRetrieving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                if let progress = viewModel.progress {
                    // Progress bar
                    ProgressView(
                        value: Double(progress.completed),
                        total: Double(progress.total)
                    )
                    .progressViewStyle(LinearProgressViewStyle())
                    
                    // Status text
                    Text("Retrieved \(progress.completed) of \(progress.total) images")
                        .font(.subheadline)
                    
                    if progress.failed > 0 {
                        Text("\(progress.failed) failed")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Remaining count
                    Text("\(progress.remaining) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text(error)
                    .multilineTextAlignment(.center)
            } else if !viewModel.retrievedImages.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Retrieved \(viewModel.retrievedImages.count) images")
            }
        }
        .padding()
    }
}

// Series row with retrieve button
struct SeriesRowWithRetrieve: View {
    let server: PACSServer
    let studyUID: String
    let series: SeriesResult
    @State private var viewModel = RetrieveViewModel()
    
    var body: some View {
        VStack {
            SeriesRowView(series: series)
            
            Button(action: {
                viewModel.retrieveSeries(
                    server: server,
                    studyUID: studyUID,
                    seriesUID: series.seriesInstanceUID ?? ""
                )
            }) {
                Label("Retrieve Images", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.isRetrieving)
            
            if viewModel.isRetrieving || viewModel.progress != nil {
                RetrieveProgressView(viewModel: viewModel)
            }
        }
    }
}
```

### 2.3 Basic Image Rendering

**Deliverables:**
- [ ] Parse retrieved DICOM files
- [ ] Extract pixel data
- [ ] Render images using `PixelDataRenderer`
- [ ] Display in SwiftUI view

**Implementation Pointers:**
```swift
// Render retrieved DICOM images
struct ImageViewer: View {
    let dicomFiles: [DICOMFile]
    @State private var currentIndex = 0
    @State private var currentImage: CGImage?
    
    var body: some View {
        VStack {
            if let image = currentImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ContentUnavailableView(
                    "No Image",
                    systemImage: "photo.badge.exclamationmark"
                )
            }
            
            // Navigation controls
            if dicomFiles.count > 1 {
                HStack {
                    Button("Previous") {
                        currentIndex = max(0, currentIndex - 1)
                        renderCurrentImage()
                    }
                    .disabled(currentIndex == 0)
                    
                    Text("\(currentIndex + 1) / \(dicomFiles.count)")
                    
                    Button("Next") {
                        currentIndex = min(dicomFiles.count - 1, currentIndex + 1)
                        renderCurrentImage()
                    }
                    .disabled(currentIndex >= dicomFiles.count - 1)
                }
            }
        }
        .onAppear {
            renderCurrentImage()
        }
    }
    
    func renderCurrentImage() {
        guard currentIndex < dicomFiles.count else { return }
        let file = dicomFiles[currentIndex]
        
        guard let pixelData = file.pixelData() else {
            currentImage = nil
            return
        }
        
        let paletteColorLUT = file.paletteColorLUT()
        let renderer = PixelDataRenderer(
            pixelData: pixelData,
            paletteColorLUT: paletteColorLUT
        )
        
        currentImage = renderer.renderFrame(0)
    }
}
```

**Key APIs:**
- `DICOMFile.read(from: Data)` - Parse DICOM data
- `DICOMFile.pixelData()` - Extract pixel data
- `DICOMFile.paletteColorLUT()` - Get palette for PALETTE COLOR
- `PixelDataRenderer` - Render to CGImage

### 2.4 C-MOVE Alternative (Advanced)

**Deliverables:**
- [ ] Local Storage SCP for receiving C-MOVE images
- [ ] Configure move destination AE
- [ ] Coordinate C-MOVE request with local SCP

**Implementation Pointers:**
```swift
// C-MOVE requires a local SCP to receive images
// This is more complex but needed for some PACS configurations

// Start local Storage SCP
actor LocalStorageSCP {
    private var server: DICOMStorageServer?
    let storageDirectory: URL
    var receivedFiles: [URL] = []
    
    init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
    }
    
    func start(aeTitle: String, port: UInt16) async throws {
        let config = StorageSCPConfiguration(
            aeTitle: try AETitle(aeTitle),
            port: port,
            acceptedSOPClasses: CommonStorageSOPClasses.all,
            acceptedTransferSyntaxes: CommonTransferSyntaxes.all
        )
        
        let delegate = LocalStorageDelegate(
            directory: storageDirectory,
            onFileReceived: { [weak self] url in
                await self?.addReceivedFile(url)
            }
        )
        
        server = DICOMStorageServer(
            configuration: config,
            delegate: delegate
        )
        
        try await server?.start()
    }
    
    func stop() async {
        await server?.stop()
    }
    
    private func addReceivedFile(_ url: URL) {
        receivedFiles.append(url)
    }
}

// C-MOVE request
func retrieveWithMove(
    server: PACSServer,
    studyUID: String,
    seriesUID: String,
    destinationAE: String
) async throws {
    let config = try DICOMClientConfiguration(
        host: server.host,
        port: server.port,
        callingAE: server.callingAETitle,
        calledAE: server.calledAETitle
    )
    
    let client = DICOMClient(configuration: config)
    
    let progressStream = try await client.moveSeries(
        studyInstanceUID: studyUID,
        seriesInstanceUID: seriesUID,
        destinationAETitle: destinationAE,
        priority: .medium
    )
    
    for try await event in progressStream {
        switch event {
        case .progress(let p):
            print("Move progress: \(p.completed)/\(p.total)")
        case .completed(let result):
            print("Move completed: \(result.completed) sent")
        case .error(let error):
            throw error
        }
    }
}
```

**Note:** C-GET is recommended for most client applications as it's simpler and doesn't require running a local SCP.

### Phase 2 Acceptance Criteria

- [ ] C-GET retrieves images successfully from PACS
- [ ] Progress is displayed during retrieval
- [ ] Retrieved images are rendered correctly
- [ ] Multi-image series navigation works
- [ ] Errors during retrieval are handled gracefully
- [ ] Works on iOS, macOS, and visionOS

---

## Phase 3: Image Display & Manipulation (2-3 weeks)

**Goal**: Add interactive image manipulation and multi-frame navigation capabilities.

### 3.1 Window/Level Controls

**Deliverables:**
- [ ] Interactive window/level adjustment
- [ ] Preset window/level values per modality
- [ ] Real-time image update
- [ ] Reset to default functionality

**Implementation Pointers:**
```swift
// Window/Level with PixelDataRenderer
@Observable
class ImageViewModel {
    var windowCenter: Double
    var windowWidth: Double
    
    func updateWindow(center: Double, width: Double) {
        self.windowCenter = center
        self.windowWidth = width
        renderWithCurrentSettings()
    }
    
    func renderWithCurrentSettings() -> CGImage? {
        guard let pixelData = currentPixelData else { return nil }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        let window = WindowSettings(center: windowCenter, width: windowWidth)
        
        return renderer.renderMonochromeFrame(currentFrame, window: window)
    }
}

// Common window presets by modality
enum WindowPreset {
    case ctAbdomen  // Center: 40, Width: 400
    case ctLung     // Center: -600, Width: 1500
    case ctBone     // Center: 400, Width: 1800
    case ctBrain    // Center: 40, Width: 80
    
    var settings: WindowSettings {
        switch self {
        case .ctAbdomen: return WindowSettings(center: 40, width: 400)
        case .ctLung: return WindowSettings(center: -600, width: 1500)
        case .ctBone: return WindowSettings(center: 400, width: 1800)
        case .ctBrain: return WindowSettings(center: 40, width: 80)
        }
    }
}

// Read window values from DICOM if present
let windowCenter = dataSet.double(for: .windowCenter)
let windowWidth = dataSet.double(for: .windowWidth)
```

**Key APIs:**
- `WindowSettings(center:width:)` - Create window settings
- `PixelDataRenderer.renderMonochromeFrame(_:window:)` - Apply window

### 3.2 Pan and Zoom

**Deliverables:**
- [ ] Pinch/scroll to zoom
- [ ] Drag to pan
- [ ] Fit to window option
- [ ] 1:1 pixel display option
- [ ] Zoom percentage indicator

**Implementation Pointers:**
```swift
struct InteractiveImageView: View {
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureOffset: CGSize = .zero
    
    var body: some View {
        Image(decorative: cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale * gestureScale)
            .offset(x: offset.width + gestureOffset.width,
                    y: offset.height + gestureOffset.height)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
    }
    
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale *= value
                scale = max(0.1, min(scale, 10.0))
            }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}
```

### 3.3 Multi-Frame Navigation

**Deliverables:**
- [ ] Frame slider for multi-frame images
- [ ] Play/pause animation (cine mode)
- [ ] Adjustable frame rate
- [ ] Frame number display
- [ ] Keyboard shortcuts for frame navigation

**Implementation Pointers:**
```swift
@Observable
class MultiFrameViewModel {
    var currentFrame: Int = 0
    var totalFrames: Int = 1
    var isPlaying: Bool = false
    var frameRate: Double = 10.0
    
    private var playbackTask: Task<Void, Never>?
    
    func loadPixelData(_ pixelData: PixelData) {
        self.totalFrames = pixelData.frameCount
        self.currentFrame = 0
    }
    
    func nextFrame() {
        currentFrame = (currentFrame + 1) % totalFrames
    }
    
    func previousFrame() {
        currentFrame = (currentFrame - 1 + totalFrames) % totalFrames
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }
    
    private func startPlayback() {
        playbackTask = Task {
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .seconds(1.0 / frameRate))
                await MainActor.run { nextFrame() }
            }
        }
    }
    
    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
    }
}
```

### 3.4 Image Rotation and Flip

**Deliverables:**
- [ ] Rotate 90° clockwise/counterclockwise
- [ ] Rotate 180°
- [ ] Horizontal flip
- [ ] Vertical flip
- [ ] Reset transformations

**Implementation Pointers:**
```swift
struct TransformableImageView: View {
    @State private var rotation: Angle = .zero
    @State private var flipHorizontal: Bool = false
    @State private var flipVertical: Bool = false
    
    var body: some View {
        Image(decorative: cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .rotationEffect(rotation)
            .scaleEffect(x: flipHorizontal ? -1 : 1, 
                        y: flipVertical ? -1 : 1)
    }
    
    func rotateClockwise() {
        rotation += .degrees(90)
    }
    
    func rotateCounterClockwise() {
        rotation -= .degrees(90)
    }
    
    func toggleHorizontalFlip() {
        flipHorizontal.toggle()
    }
    
    func toggleVerticalFlip() {
        flipVertical.toggle()
    }
    
    func resetTransformations() {
        rotation = .zero
        flipHorizontal = false
        flipVertical = false
    }
}
```

### Phase 3 Acceptance Criteria

- [ ] Interactive window/level with mouse/touch gestures
- [ ] Modality-specific window presets work correctly
- [ ] Smooth pan and zoom with pinch/scroll gestures
- [ ] Multi-frame navigation with slider and animation
- [ ] Rotation and flip operations work correctly
- [ ] Keyboard shortcuts for power users

---

## Phase 4: Advanced Viewing Features (2-3 weeks)

**Goal**: Implement advanced DICOM viewing capabilities including measurements and annotations.

### 4.1 Measurement Tools

**Deliverables:**
- [ ] Distance measurement (line tool)
- [ ] Area measurement (rectangle, ellipse)
- [ ] Angle measurement
- [ ] Pixel value probe (Hounsfield Units for CT)
- [ ] Calibrated measurements using Pixel Spacing

**Implementation Pointers:**
```swift
// Get pixel spacing for calibrated measurements
struct PixelSpacing {
    let rowSpacing: Double  // mm per pixel (row direction)
    let columnSpacing: Double  // mm per pixel (column direction)
    
    init?(from dataSet: DataSet) {
        guard let values = dataSet.doubles(for: .pixelSpacing),
              values.count >= 2 else { return nil }
        self.rowSpacing = values[0]
        self.columnSpacing = values[1]
    }
}

// Calculate distance in mm
func calculateDistance(from start: CGPoint, to end: CGPoint, 
                       pixelSpacing: PixelSpacing) -> Double {
    let dx = (end.x - start.x) * pixelSpacing.columnSpacing
    let dy = (end.y - start.y) * pixelSpacing.rowSpacing
    return sqrt(dx * dx + dy * dy)
}

// Get Hounsfield Unit value at pixel
func getHounsfieldUnit(at point: CGPoint, pixelData: PixelData, 
                       dataSet: DataSet) -> Int? {
    let rescaleSlope = dataSet.double(for: .rescaleSlope) ?? 1.0
    let rescaleIntercept = dataSet.double(for: .rescaleIntercept) ?? 0.0
    
    guard let rawValue = pixelData.pixelValue(at: Int(point.x), 
                                               y: Int(point.y), 
                                               frame: 0) else {
        return nil
    }
    
    return Int(Double(rawValue) * rescaleSlope + rescaleIntercept)
}

// Measurement annotation model
struct MeasurementAnnotation: Identifiable {
    let id = UUID()
    let type: MeasurementType
    let points: [CGPoint]
    var result: MeasurementResult
}

enum MeasurementType {
    case distance
    case area
    case angle
    case probe
}

struct MeasurementResult {
    let value: Double
    let unit: String
    let displayText: String
}
```

**Key Tags:**
- `pixelSpacing` (0028,0030) - Physical spacing between pixels
- `rescaleSlope` (0028,1053) - Slope for converting to HU
- `rescaleIntercept` (0028,1052) - Intercept for converting to HU
- `imagerPixelSpacing` (0018,1164) - For projection radiography

### 4.2 DICOM Tag Browser

**Deliverables:**
- [ ] Hierarchical tree view of all DICOM elements
- [ ] Group name and tag display
- [ ] VR and value display
- [ ] Search/filter functionality
- [ ] Sequence expansion

**Implementation Pointers:**
```swift
// Iterate through all data elements
func buildTagTree(from dataSet: DataSet) -> [TagNode] {
    var nodes: [TagNode] = []
    
    for element in dataSet.elements.sorted(by: { $0.tag < $1.tag }) {
        let node = TagNode(
            tag: element.tag,
            tagName: element.tag.name ?? "Unknown",
            groupName: element.tag.groupName,
            vr: element.vr,
            value: formatValue(element),
            children: element.vr == .sq ? buildSequenceChildren(element) : []
        )
        nodes.append(node)
    }
    
    return nodes
}

// Format value for display
func formatValue(_ element: DataElement) -> String {
    switch element.vr {
    case .pn:
        if let pn = element.personName {
            return "\(pn.familyName), \(pn.givenName)"
        }
    case .da:
        if let date = element.date {
            return "\(date.year)-\(date.month)-\(date.day)"
        }
    case .tm:
        if let time = element.time {
            return String(format: "%02d:%02d:%02d", 
                         time.hour, time.minute, time.second)
        }
    case .sq:
        let count = element.sequenceItems?.count ?? 0
        return "Sequence (\(count) items)"
    default:
        if let str = element.string {
            return str
        }
    }
    return element.description
}

// SwiftUI Tag Browser View
struct TagBrowserView: View {
    let dataSet: DataSet
    @State private var searchText = ""
    @State private var expandedTags: Set<Tag> = []
    
    var body: some View {
        List {
            ForEach(filteredElements) { node in
                TagRowView(node: node, isExpanded: $expandedTags)
            }
        }
        .searchable(text: $searchText, prompt: "Search tags...")
    }
}
```

### 4.3 Image Comparison (2-Up, 4-Up Views)

**Deliverables:**
- [ ] Side-by-side comparison (2-up)
- [ ] Quad view (4-up)
- [ ] Synchronized scrolling option
- [ ] Synchronized window/level
- [ ] Cross-reference lines

**Implementation Pointers:**
```swift
struct ComparisonView: View {
    @State private var layout: ViewLayout = .twoUp
    @State private var synchronizeScroll: Bool = true
    @State private var synchronizeWindow: Bool = true
    
    var body: some View {
        switch layout {
        case .single:
            ImagePanelView(viewModel: viewModels[0])
        case .twoUp:
            HStack(spacing: 1) {
                ImagePanelView(viewModel: viewModels[0])
                ImagePanelView(viewModel: viewModels[1])
            }
        case .fourUp:
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    ImagePanelView(viewModel: viewModels[0])
                    ImagePanelView(viewModel: viewModels[1])
                }
                HStack(spacing: 1) {
                    ImagePanelView(viewModel: viewModels[2])
                    ImagePanelView(viewModel: viewModels[3])
                }
            }
        }
    }
}

enum ViewLayout {
    case single
    case twoUp
    case fourUp
}

// Synchronization logic
@Observable
class SynchronizedViewManager {
    var viewModels: [ImageViewModel]
    var synchronizeFrame: Bool = true
    var synchronizeWindow: Bool = true
    
    func updateFrame(_ frame: Int, source: ImageViewModel) {
        guard synchronizeFrame else { return }
        for vm in viewModels where vm !== source {
            vm.currentFrame = frame
        }
    }
    
    func updateWindow(_ window: WindowSettings, source: ImageViewModel) {
        guard synchronizeWindow else { return }
        for vm in viewModels where vm !== source {
            vm.windowSettings = window
        }
    }
}
```

### 4.4 Export Capabilities

**Deliverables:**
- [ ] Export current view as PNG/JPEG
- [ ] Export all frames as image sequence
- [ ] Export with annotations
- [ ] Copy to clipboard
- [ ] Share sheet integration (iOS)

**Implementation Pointers:**
```swift
// Export current frame as image
func exportImage(format: ImageFormat) async -> Data? {
    guard let cgImage = currentRenderedImage else { return nil }
    
    #if canImport(AppKit)
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, 
                                                          height: cgImage.height))
    switch format {
    case .png:
        return nsImage.pngData()
    case .jpeg(let quality):
        return nsImage.jpegData(compressionQuality: quality)
    }
    #elseif canImport(UIKit)
    let uiImage = UIImage(cgImage: cgImage)
    switch format {
    case .png:
        return uiImage.pngData()
    case .jpeg(let quality):
        return uiImage.jpegData(compressionQuality: quality)
    }
    #endif
}

// Export all frames
func exportAllFrames(to directory: URL, format: ImageFormat) async throws {
    for frameIndex in 0..<pixelData.frameCount {
        let renderer = PixelDataRenderer(pixelData: pixelData)
        guard let image = renderer.renderFrame(frameIndex) else { continue }
        
        let filename = String(format: "frame_%04d.\(format.extension)", frameIndex)
        let fileURL = directory.appendingPathComponent(filename)
        
        let data = try exportFrame(image, format: format)
        try data.write(to: fileURL)
    }
}

enum ImageFormat {
    case png
    case jpeg(quality: CGFloat)
    
    var `extension`: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}
```

### Phase 4 Acceptance Criteria

- [ ] Distance measurements are calibrated and accurate
- [ ] HU probe displays correct values for CT images
- [ ] Tag browser shows all DICOM elements with proper formatting
- [ ] Comparison views support synchronized navigation
- [ ] Export produces high-quality images
- [ ] All features work across platforms

---

## Phase 5: Study Management & Organization (2-3 weeks)

**Goal**: Implement study organization, local database, and study management features.

### 5.1 Local Study Database

**Deliverables:**
- [ ] SQLite or SwiftData database for study index
- [ ] Import studies from files
- [ ] Track study metadata
- [ ] Quick access to recent studies
- [ ] Search local studies

**Implementation Pointers:**
```swift
// SwiftData model for local studies
@Model
class LocalStudy {
    var studyInstanceUID: String
    var patientName: String?
    var patientID: String?
    var studyDate: Date?
    var studyDescription: String?
    var modality: String?
    var numberOfSeries: Int
    var numberOfInstances: Int
    var localPath: URL
    var importDate: Date
    
    @Relationship(deleteRule: .cascade)
    var series: [LocalSeries]
}

@Model
class LocalSeries {
    var seriesInstanceUID: String
    var seriesDescription: String?
    var seriesNumber: Int?
    var modality: String?
    var numberOfInstances: Int
    
    @Relationship(inverse: \LocalStudy.series)
    var study: LocalStudy?
    
    @Relationship(deleteRule: .cascade)
    var instances: [LocalInstance]
}

@Model
class LocalInstance {
    var sopInstanceUID: String
    var sopClassUID: String
    var instanceNumber: Int?
    var filePath: URL
    
    @Relationship(inverse: \LocalSeries.instances)
    var series: LocalSeries?
}

// Import DICOM file to database
func importDICOMFile(_ fileURL: URL) throws {
    let data = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile.read(from: data)
    let dataSet = dicomFile.dataSet
    
    let studyUID = dataSet.string(for: .studyInstanceUID) ?? UUID().uuidString
    
    // Find or create study
    let study = findOrCreateStudy(studyUID: studyUID, dataSet: dataSet)
    
    // Find or create series
    let seriesUID = dataSet.string(for: .seriesInstanceUID) ?? UUID().uuidString
    let series = findOrCreateSeries(seriesUID: seriesUID, 
                                     study: study, 
                                     dataSet: dataSet)
    
    // Create instance
    let sopInstanceUID = dataSet.string(for: .sopInstanceUID) ?? UUID().uuidString
    let instance = LocalInstance(
        sopInstanceUID: sopInstanceUID,
        sopClassUID: dataSet.string(for: .sopClassUID) ?? "",
        instanceNumber: dataSet.int(for: .instanceNumber),
        filePath: fileURL
    )
    instance.series = series
    
    modelContext.insert(instance)
    try modelContext.save()
}
```

### 5.2 Study List View

**Deliverables:**
- [ ] Master list of all local studies
- [ ] Sorting options (date, patient, modality)
- [ ] Filtering and search
- [ ] Study thumbnails
- [ ] Study details panel

**Implementation Pointers:**
```swift
struct StudyListView: View {
    @Query(sort: \LocalStudy.importDate, order: .reverse)
    private var studies: [LocalStudy]
    
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var modalityFilter: String?
    
    var filteredStudies: [LocalStudy] {
        studies.filter { study in
            // Apply search filter
            if !searchText.isEmpty {
                let matchesName = study.patientName?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesID = study.patientID?.localizedCaseInsensitiveContains(searchText) ?? false
                let matchesDesc = study.studyDescription?.localizedCaseInsensitiveContains(searchText) ?? false
                if !matchesName && !matchesID && !matchesDesc {
                    return false
                }
            }
            
            // Apply modality filter
            if let filter = modalityFilter, study.modality != filter {
                return false
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(filteredStudies) { study in
                NavigationLink(value: study) {
                    StudyRowView(study: study)
                }
            }
            .searchable(text: $searchText)
            .toolbar {
                SortMenu(sortOrder: $sortOrder)
                FilterMenu(modalityFilter: $modalityFilter)
            }
        } detail: {
            StudyDetailView()
        }
    }
}

struct StudyRowView: View {
    let study: LocalStudy
    
    var body: some View {
        HStack {
            AsyncThumbnailView(study: study)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading) {
                Text(study.patientName ?? "Unknown")
                    .font(.headline)
                Text(study.studyDescription ?? "No description")
                    .font(.subheadline)
                HStack {
                    Text(study.modality ?? "")
                    Spacer()
                    if let date = study.studyDate {
                        Text(date, style: .date)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}
```

### 5.3 Folder/DICOMDIR Import

**Deliverables:**
- [ ] Import entire folder of DICOM files
- [ ] DICOMDIR file parsing
- [ ] Progress indicator for batch import
- [ ] Duplicate detection

**Implementation Pointers:**
```swift
// Batch import folder
func importFolder(_ folderURL: URL) async throws {
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(
        at: folderURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    
    var filesToImport: [URL] = []
    
    while let fileURL = enumerator?.nextObject() as? URL {
        if isDICOMFile(fileURL) {
            filesToImport.append(fileURL)
        }
    }
    
    // Import with progress
    let totalFiles = filesToImport.count
    for (index, fileURL) in filesToImport.enumerated() {
        do {
            try importDICOMFile(fileURL)
        } catch {
            print("Failed to import \(fileURL.lastPathComponent): \(error)")
        }
        
        await MainActor.run {
            self.importProgress = Double(index + 1) / Double(totalFiles)
            self.statusMessage = "Importing \(index + 1) of \(totalFiles)"
        }
    }
}

// Check if file is DICOM Part 10 format
// Note: This checks for the DICM prefix at byte offset 128, which is present in
// standard DICOM Part 10 files. Some legacy DICOM files or DICOMDIR files may not
// have this prefix. For production use, consider also attempting to parse files
// that pass extension checks (.dcm, .dicom) even if the DICM prefix is missing.
func isDICOMFile(_ url: URL) -> Bool {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
          data.count >= 132 else {
        return false
    }
    
    // Check for DICM prefix at byte 128 (standard DICOM Part 10 format)
    let dicmBytes = data[128..<132]
    return dicmBytes.elementsEqual([0x44, 0x49, 0x43, 0x4D])
}
```

### 5.4 Study Delete and Archive

**Deliverables:**
- [ ] Delete studies from local database
- [ ] Archive studies to external location
- [ ] Confirmation dialogs
- [ ] Undo delete support

**Implementation Pointers:**
```swift
// Delete study
func deleteStudy(_ study: LocalStudy) throws {
    // Delete files from disk
    let fileManager = FileManager.default
    
    for series in study.series {
        for instance in series.instances {
            try? fileManager.removeItem(at: instance.filePath)
        }
    }
    
    // Delete study folder if empty
    let studyFolder = study.localPath
    try? fileManager.removeItem(at: studyFolder)
    
    // Delete from database
    modelContext.delete(study)
    try modelContext.save()
}

// Archive study to external location
func archiveStudy(_ study: LocalStudy, to destination: URL) async throws {
    let fileManager = FileManager.default
    
    // Create study folder at destination
    let studyFolder = destination.appendingPathComponent(study.studyInstanceUID)
    try fileManager.createDirectory(at: studyFolder, withIntermediateDirectories: true)
    
    // Copy all files
    for series in study.series {
        let seriesFolder = studyFolder.appendingPathComponent(series.seriesInstanceUID)
        try fileManager.createDirectory(at: seriesFolder, withIntermediateDirectories: true)
        
        for instance in series.instances {
            let destPath = seriesFolder.appendingPathComponent(
                instance.filePath.lastPathComponent
            )
            try fileManager.copyItem(at: instance.filePath, to: destPath)
        }
    }
}
```

### Phase 5 Acceptance Criteria

- [ ] Local database indexes imported studies
- [ ] Study list displays all studies with thumbnails
- [ ] Search and filter work correctly
- [ ] Batch import handles large folders
- [ ] Delete and archive functions work correctly
- [ ] Data persists across app restarts

---

## Phase 6: Platform-Specific Features (2 weeks)

**Goal**: Implement platform-specific optimizations and features for iOS, macOS, and visionOS.

### 6.1 macOS Features

**Deliverables:**
- [ ] Native macOS menu bar
- [ ] Keyboard shortcuts
- [ ] Multiple windows support
- [ ] Drag and drop from Finder
- [ ] Quick Look preview extension

**Implementation Pointers:**
```swift
// macOS App with commands
@main
struct DICOMViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            FileCommands()
            ViewCommands()
            ToolCommands()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// Custom commands
struct FileCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open DICOM File...") {
                openFile()
            }
            .keyboardShortcut("o")
            
            Button("Import Folder...") {
                importFolder()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}

struct ViewCommands: Commands {
    @FocusedBinding(\.windowLevel) var windowLevel
    
    var body: some Commands {
        CommandMenu("View") {
            Button("Fit to Window") {
                fitToWindow()
            }
            .keyboardShortcut("0")
            
            Button("Actual Size") {
                actualSize()
            }
            .keyboardShortcut("1")
            
            Divider()
            
            Button("CT Abdomen Preset") {
                applyPreset(.ctAbdomen)
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
        }
    }
}
```

### 6.2 iOS Features

**Deliverables:**
- [ ] iOS-optimized touch gestures
- [ ] Files app integration
- [ ] Share extension for DICOM files
- [ ] iPad split view support
- [ ] Haptic feedback

**Implementation Pointers:**
```swift
// iOS touch gestures
struct iOSImageView: View {
    @State private var scale: CGFloat = 1.0
    @GestureState private var magnificationState: CGFloat = 1.0
    
    var body: some View {
        Image(decorative: cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale * magnificationState)
            .gesture(
                MagnificationGesture()
                    .updating($magnificationState) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        scale *= value
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
            )
    }
}

// Document type registration (Info.plist)
// Add to your app's Info.plist:
/*
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>DICOM Image</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.dicom.dicom</string>
        </array>
    </dict>
</array>
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
        <key>UTTypeDescription</key>
        <string>DICOM Image</string>
        <key>UTTypeIdentifier</key>
        <string>org.dicom.dicom</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>dcm</string>
                <string>dicom</string>
            </array>
        </dict>
    </dict>
</array>
*/
```

### 6.3 visionOS Features

**Deliverables:**
- [ ] Spatial image viewing
- [ ] 3D volume rendering (basic)
- [ ] Eye tracking for image selection
- [ ] Gesture-based manipulation in space
- [ ] Ornaments for metadata display

**Implementation Pointers:**
```swift
#if os(visionOS)
import RealityKit

struct VisionOSImageView: View {
    let cgImage: CGImage
    
    var body: some View {
        GeometryReader3D { geometry in
            RealityView { content in
                // Create a plane with the DICOM image as texture
                let material = createImageMaterial(from: cgImage)
                let plane = ModelEntity(
                    mesh: .generatePlane(width: 1.0, depth: 1.0),
                    materials: [material]
                )
                content.add(plane)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            MetadataOrnamentView()
        }
    }
    
    func createImageMaterial(from cgImage: CGImage) -> UnlitMaterial {
        // TODO: Implement CGImage to RealityKit texture conversion
        // Implementation would involve:
        // 1. Create TextureResource from CGImage using TextureResource.generate(from:options:)
        // 2. Create UnlitMaterial with the texture
        // 3. Configure material properties (e.g., color, opacity)
        //
        // Example (requires async context):
        // let texture = try await TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        // var material = UnlitMaterial()
        // material.color = .init(texture: .init(texture))
        // return material
        
        return UnlitMaterial()
    }
}

// Spatial study browser
struct SpatialStudyBrowserView: View {
    let studies: [LocalStudy]
    
    var body: some View {
        RealityView { content in
            // Arrange study thumbnails in 3D space
            for (index, study) in studies.enumerated() {
                let position = calculatePosition(for: index)
                let thumbnail = createThumbnailEntity(for: study)
                thumbnail.position = position
                content.add(thumbnail)
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    // Handle study selection
                }
        )
    }
}
#endif
```

### Phase 6 Acceptance Criteria

- [ ] macOS has full menu bar and keyboard shortcuts
- [ ] iOS works with Files app and share sheets
- [ ] visionOS provides spatial viewing experience
- [ ] Platform-specific gestures are natural
- [ ] All platforms maintain feature parity where applicable

---

## Phase 7: Polish & Documentation (1-2 weeks)

**Goal**: Finalize the example application with documentation and polish.

### 7.1 User Interface Polish

**Deliverables:**
- [ ] Consistent design language
- [ ] Dark mode support
- [ ] Accessibility support (VoiceOver, Dynamic Type)
- [ ] Loading states and animations
- [ ] Error states and empty states

**Implementation Pointers:**
```swift
// Accessibility support
struct AccessibleImageView: View {
    let dicomFile: DICOMFile
    let cgImage: CGImage
    
    var body: some View {
        Image(decorative: cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Double tap to view full screen")
    }
    
    var accessibilityDescription: String {
        var description = "DICOM image"
        if let patientName = dicomFile.dataSet.string(for: .patientName) {
            description += " for \(patientName)"
        }
        if let modality = dicomFile.dataSet.string(for: .modality) {
            description += ", \(modality) scan"
        }
        return description
    }
}

// Loading state
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Error state
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry", action: retryAction)
        }
    }
}
```

### 7.2 Performance Optimization

**Deliverables:**
- [ ] Memory optimization for large images
- [ ] Image caching
- [ ] Background loading
- [ ] Lazy loading for series

**Implementation Pointers:**
```swift
// Image cache
actor ImageCache {
    private var cache: NSCache<NSString, CGImageWrapper>
    
    init(countLimit: Int = 100, totalCostLimit: Int = 100_000_000) {
        cache = NSCache()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    func image(for key: String) -> CGImage? {
        cache.object(forKey: key as NSString)?.image
    }
    
    func setImage(_ image: CGImage, for key: String) {
        let wrapper = CGImageWrapper(image: image)
        let cost = image.width * image.height * 4
        cache.setObject(wrapper, forKey: key as NSString, cost: cost)
    }
}

class CGImageWrapper: NSObject {
    let image: CGImage
    init(image: CGImage) { self.image = image }
}

// Background loading with priority
func loadImageInBackground(sopInstanceUID: String) async -> CGImage? {
    return await Task.detached(priority: .userInitiated) {
        // Load and render image
        guard let data = try? loadDICOMData(sopInstanceUID: sopInstanceUID),
              let dicomFile = try? DICOMFile.read(from: data),
              let pixelData = dicomFile.pixelData() else {
            return nil
        }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        return renderer.renderFrame(0)
    }.value
}
```

### 7.3 Documentation

**Deliverables:**
- [ ] README with setup instructions
- [ ] Code comments and documentation
- [ ] Architecture documentation
- [ ] User guide with screenshots

**Documentation Structure:**
```
DICOMViewer/
├── README.md                    # Overview, features, setup
├── ARCHITECTURE.md              # Technical architecture
├── docs/
│   ├── user-guide.md           # End-user documentation
│   ├── development.md          # Developer setup
│   └── screenshots/            # UI screenshots
└── Sources/
    └── (inline documentation)
```

### 7.4 Testing

**Deliverables:**
- [ ] Unit tests for view models
- [ ] UI tests for critical flows
- [ ] Test with sample DICOM files
- [ ] Performance benchmarks

**Implementation Pointers:**
```swift
// View model tests
@Test
func testImageRendering() async throws {
    let viewModel = ImageViewModel()
    let testData = try loadTestDICOMFile("ct_sample.dcm")
    
    await viewModel.loadFile(testData)
    
    #expect(viewModel.cgImage != nil)
    #expect(viewModel.pixelData?.frameCount == 1)
}

@Test
func testWindowLevel() async throws {
    let viewModel = ImageViewModel()
    let testData = try loadTestDICOMFile("ct_sample.dcm")
    
    await viewModel.loadFile(testData)
    viewModel.updateWindow(center: 40, width: 400)
    
    #expect(viewModel.windowSettings.center == 40)
    #expect(viewModel.windowSettings.width == 400)
}

// UI tests
@MainActor
@Test
func testFileOpen() async throws {
    let app = XCUIApplication()
    app.launch()
    
    // Open file picker
    app.buttons["Open File"].tap()
    
    // Select test file
    // ...
    
    // Verify image displayed
    #expect(app.images["dicomImage"].exists)
}
```

### Phase 7 Acceptance Criteria

- [ ] UI is polished and consistent across platforms
- [ ] Dark mode works correctly
- [ ] VoiceOver can navigate all UI elements
- [ ] Performance is acceptable with large studies
- [ ] Documentation is complete and accurate
- [ ] Tests provide reasonable coverage

---

## Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| 1 | 2-3 weeks | **PACS Connectivity** - Patient query (C-ECHO, C-FIND) |
| 2 | 2-3 weeks | **Image Retrieval** - Download from PACS (C-GET, C-MOVE) |
| 3 | 2-3 weeks | **Image Display** - Window/level, pan, zoom, multi-frame |
| 4 | 2-3 weeks | **Advanced Viewing** - Measurements, tag browser, comparison |
| 5 | 2-3 weeks | **Study Management** - Local database, import, organization |
| 6 | 2 weeks | **Platform-Specific** - macOS, iOS, visionOS optimizations |
| 7 | 1-2 weeks | **Polish** - Documentation, testing, accessibility |

**Total Estimated Duration**: 15-20 weeks

## Development Priority

This plan follows a **PACS-first approach** where network connectivity is prioritized:

1. ✅ **Phase 1-2**: Connect to PACS, query patients, retrieve images
2. ✅ **Phase 3-4**: Display and manipulate retrieved images
3. ✅ **Phase 5-7**: Polish, management, and platform optimization

This approach allows the application to be immediately useful in clinical workflows where data primarily comes from PACS systems rather than local files.

## Getting Started

1. Create a new Xcode project (App template, SwiftUI, Multi-platform)
2. Add DICOMKit as a Swift Package dependency:
   ```swift
   .package(url: "https://github.com/raster-image/DICOMKit.git", from: "0.7.0")
   ```
3. Import DICOMNetwork for PACS connectivity:
   ```swift
   import DICOMKit
   import DICOMCore
   import DICOMNetwork
   ```
4. Follow Phase 1 - start with PACS server configuration and patient query
5. Test with a DICOM test server (e.g., Orthanc, dcm4chee)

## Resources

- [DICOMKit Repository](https://github.com/raster-image/DICOMKit)
- [DICOM Standard](https://www.dicomstandard.org/)
- [Sample DICOM Files](https://www.dicomlibrary.com/)
- [Orthanc Test Server](https://www.orthanc-server.com/) - Free DICOM server for testing
- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple visionOS Documentation](https://developer.apple.com/visionos/)
