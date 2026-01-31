# DICOMViewer Example Application - Development Plan

This document outlines a comprehensive phased development plan for creating an example DICOMViewer application using DICOMKit. The application will demonstrate the full capabilities of DICOMKit while providing a real-world reference implementation for developers.

## Overview

The DICOMViewer example application will be a cross-platform SwiftUI application supporting iOS, macOS, and visionOS. It will showcase:

- DICOM file reading and rendering
- PACS connectivity (Query/Retrieve)
- Image manipulation (windowing, pan, zoom)
- Multi-frame/series navigation
- DICOM network operations

---

## Phase 1: Foundation - Basic File Viewer (2-3 weeks)

**Goal**: Create a minimal viable DICOM viewer that can open, display, and inspect DICOM files.

### 1.1 Project Setup

**Deliverables:**
- [ ] Create new SwiftUI App project using Xcode
- [ ] Configure for multi-platform (iOS 17+, macOS 14+, visionOS 1.0+)
- [ ] Add DICOMKit as Swift Package dependency
- [ ] Set up project structure following MVVM architecture

**Implementation Pointers:**
```swift
// Package.swift or Xcode project dependency
.package(url: "https://github.com/raster-image/DICOMKit.git", from: "0.7.0")

// Required imports
import DICOMKit
import DICOMCore
```

**Directory Structure:**
```
DICOMViewer/
├── App/
│   ├── DICOMViewerApp.swift
│   └── AppState.swift
├── Models/
│   ├── DICOMDocument.swift
│   └── ViewerState.swift
├── Views/
│   ├── ContentView.swift
│   ├── ImageView.swift
│   ├── MetadataView.swift
│   └── Components/
├── ViewModels/
│   ├── ImageViewModel.swift
│   └── MetadataViewModel.swift
├── Services/
│   ├── DICOMFileService.swift
│   └── ImageRenderingService.swift
└── Resources/
```

### 1.2 File Import

**Deliverables:**
- [ ] Implement file picker for DICOM files (.dcm, .dicom)
- [ ] Support drag-and-drop on macOS
- [ ] iOS document picker integration
- [ ] Error handling for invalid files

**Implementation Pointers:**
```swift
// File reading with DICOMKit
func loadDICOMFile(from url: URL) async throws -> DICOMFile {
    let data = try Data(contentsOf: url)
    return try DICOMFile.read(from: data)
}

// Document type declaration (Info.plist)
// UTI: org.dicom.dicom
// File extensions: dcm, dicom
```

**Key APIs:**
- `DICOMFile.read(from: Data)` - Parse DICOM data
- `UniformTypeIdentifiers` - Define document types
- `NSOpenPanel` (macOS) / `UIDocumentPickerViewController` (iOS)

### 1.3 Basic Image Rendering

**Deliverables:**
- [ ] Extract pixel data from DICOM files
- [ ] Render images using `PixelDataRenderer`
- [ ] Display images in SwiftUI view
- [ ] Handle different photometric interpretations

**Implementation Pointers:**
```swift
// Extract and render pixel data
func renderImage(from dicomFile: DICOMFile) -> CGImage? {
    guard let pixelData = dicomFile.pixelData() else { return nil }
    
    // Create renderer with optional palette LUT
    let paletteColorLUT = dicomFile.paletteColorLUT()
    let renderer = PixelDataRenderer(
        pixelData: pixelData,
        paletteColorLUT: paletteColorLUT
    )
    
    return renderer.renderFrame(0)
}

// SwiftUI Image Display
struct DICOMImageView: View {
    let cgImage: CGImage?
    
    var body: some View {
        if let image = cgImage {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ContentUnavailableView("No Image", 
                systemImage: "photo.badge.exclamationmark")
        }
    }
}
```

**Key APIs:**
- `DICOMFile.pixelData()` - Extract pixel data with descriptor
- `DICOMFile.paletteColorLUT()` - Get palette for PALETTE COLOR images
- `PixelDataRenderer` - Render to CGImage
- `PixelDataRenderer.renderFrame(_:)` - Render specific frame
- `PixelDataRenderer.renderMonochromeFrame(_:window:)` - With custom window

### 1.4 Basic Metadata Display

**Deliverables:**
- [ ] Display essential DICOM attributes
- [ ] Patient information panel
- [ ] Study/Series information
- [ ] Image parameters display

**Implementation Pointers:**
```swift
// Accessing DICOM metadata
struct PatientInfo {
    let name: String?
    let id: String?
    let birthDate: DICOMDate?
    let sex: String?
    
    init(from dataSet: DataSet) {
        self.name = dataSet.string(for: .patientName)
        self.id = dataSet.string(for: .patientID)
        self.birthDate = dataSet.date(for: .patientBirthDate)
        self.sex = dataSet.string(for: .patientSex)
    }
}

// Display formatted person name
if let personName = dataSet.personName(for: .patientName) {
    Text("\(personName.familyName), \(personName.givenName)")
}

// Format DICOM date for display
if let studyDate = dataSet.date(for: .studyDate),
   let foundationDate = studyDate.toDate() {
    Text(foundationDate, style: .date)
}
```

**Key Tags to Display:**
- Patient: `patientName`, `patientID`, `patientBirthDate`, `patientSex`
- Study: `studyDate`, `studyTime`, `studyDescription`, `accessionNumber`
- Series: `seriesDescription`, `modality`, `seriesNumber`
- Image: `rows`, `columns`, `bitsAllocated`, `photometricInterpretation`

### 1.5 Transfer Syntax Handling

**Deliverables:**
- [ ] Display current transfer syntax
- [ ] Handle all supported compression types
- [ ] Graceful degradation for unsupported formats

**Implementation Pointers:**
```swift
// Check transfer syntax
if let tsUID = dicomFile.transferSyntaxUID {
    let transferSyntax = TransferSyntax(uid: tsUID)
    print("Transfer Syntax: \(transferSyntax.name)")
    print("Compressed: \(transferSyntax.isCompressed)")
}

// DICOMKit automatically handles decompression for supported formats:
// - JPEG Baseline, Extended, Lossless
// - JPEG 2000 (Lossless and Lossy)
// - RLE Lossless
```

### Phase 1 Acceptance Criteria

- [ ] Can open single DICOM files from disk
- [ ] Displays medical images correctly (CT, MR, X-ray, US)
- [ ] Shows basic patient/study/series metadata
- [ ] Handles both uncompressed and compressed images
- [ ] Works on iOS, macOS, and visionOS
- [ ] Error messages for unsupported files

---

## Phase 2: Image Manipulation & Navigation (2-3 weeks)

**Goal**: Add interactive image manipulation and multi-frame navigation capabilities.

### 2.1 Window/Level Controls

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

**UI Components:**
- Slider controls for window center and width
- Preset buttons (CT Abdomen, CT Lung, CT Bone, etc.)
- Mouse drag gesture for interactive adjustment
- Double-tap/click to reset

### 2.2 Pan and Zoom

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
                scale = max(0.1, min(scale, 10.0)) // Clamp zoom
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
    
    func fitToWindow() {
        scale = 1.0
        offset = .zero
    }
    
    func actualSize() {
        // Calculate scale to show 1:1 pixels
        scale = CGFloat(imageWidth) / containerWidth
    }
}
```

### 2.3 Multi-Frame Navigation

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
    var frameRate: Double = 10.0 // frames per second
    
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
                await MainActor.run {
                    nextFrame()
                }
            }
        }
    }
    
    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
    }
}

// Get frame count from pixel data
let frameCount = pixelData.frameCount

// Render specific frame
let frameImage = renderer.renderFrame(frameIndex)
```

**Key APIs:**
- `PixelData.frameCount` - Number of frames
- `PixelData.frameData(at:)` - Get specific frame data
- `PixelDataRenderer.renderFrame(_:)` - Render specific frame

### 2.4 Image Rotation and Flip

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

### Phase 2 Acceptance Criteria

- [ ] Interactive window/level with mouse/touch gestures
- [ ] Modality-specific window presets work correctly
- [ ] Smooth pan and zoom with pinch/scroll gestures
- [ ] Multi-frame navigation with slider and animation
- [ ] Rotation and flip operations work correctly
- [ ] Keyboard shortcuts for power users

---

## Phase 3: Advanced Viewing Features (2-3 weeks)

**Goal**: Implement advanced DICOM viewing capabilities including measurements and annotations.

### 3.1 Measurement Tools

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

### 3.2 DICOM Tag Browser

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

### 3.3 Image Comparison (2-Up, 4-Up Views)

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

### 3.4 Export Capabilities

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

### Phase 3 Acceptance Criteria

- [ ] Distance measurements are calibrated and accurate
- [ ] HU probe displays correct values for CT images
- [ ] Tag browser shows all DICOM elements with proper formatting
- [ ] Comparison views support synchronized navigation
- [ ] Export produces high-quality images
- [ ] All features work across platforms

---

## Phase 4: PACS Connectivity (3-4 weeks)

**Goal**: Implement full DICOM network connectivity for querying and retrieving studies from PACS.

### 4.1 Server Configuration

**Deliverables:**
- [ ] Server connection settings UI
- [ ] AE Title configuration
- [ ] Host/Port/TLS settings
- [ ] Connection test (C-ECHO)
- [ ] Save/load server configurations

**Implementation Pointers:**
```swift
// Server configuration model
struct PACSServer: Codable, Identifiable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int
    var calledAETitle: String
    var callingAETitle: String
    var useTLS: Bool
    var tlsConfiguration: TLSConfiguration?
}

// Test connection with C-ECHO
func testConnection(server: PACSServer) async throws -> Bool {
    let verificationService = VerificationService()
    
    let configuration = VerificationConfiguration(
        callingAETitle: server.callingAETitle,
        calledAETitle: server.calledAETitle,
        timeout: .seconds(10)
    )
    
    let result = try await verificationService.verify(
        host: server.host,
        port: server.port,
        configuration: configuration
    )
    
    return result.success
}

// Using DICOMClient for unified API
let clientConfig = DICOMClientConfiguration(
    host: server.host,
    port: server.port,
    callingAETitle: server.callingAETitle,
    calledAETitle: server.calledAETitle,
    tlsConfiguration: server.useTLS ? .default : nil
)

let client = DICOMClient(configuration: clientConfig)

// Test connection
let verificationResult = try await client.verify()
print("Connection test: \(verificationResult.success ? "Success" : "Failed")")
```

**Key APIs:**
- `VerificationService` - C-ECHO verification
- `DICOMClient` - Unified high-level API
- `DICOMClientConfiguration` - Connection settings
- `TLSConfiguration` - Security settings

### 4.2 Patient/Study Query

**Deliverables:**
- [ ] Search form with common query fields
- [ ] Patient name search (with wildcards)
- [ ] Date range search
- [ ] Modality filter
- [ ] Accession number search
- [ ] Query results display

**Implementation Pointers:**
```swift
// Using DICOMClient for queries
func searchStudies(criteria: SearchCriteria) async throws -> [StudyResult] {
    let queryKeys = QueryKeys()
        .set(patientName: criteria.patientName)
        .set(patientID: criteria.patientID)
        .set(studyDate: criteria.studyDateRange)
        .set(modality: criteria.modality)
        .set(accessionNumber: criteria.accessionNumber)
    
    // Using DICOMClient
    return try await client.findStudies(matching: queryKeys)
}

// Search criteria model
struct SearchCriteria {
    // Supports DICOM wildcards:
    // - '*' matches zero or more characters (e.g., "SMITH*" matches "SMITH", "SMITHSON")
    // - '?' matches exactly one character (e.g., "SM?TH" matches "SMITH", "SMYTH")
    var patientName: String?
    var patientID: String?
    var studyDateRange: String?   // Format: "20240101-20241231"
    var modality: String?         // "CT", "MR", "CR", etc.
    var accessionNumber: String?
}

// Display query results
struct StudySearchResultsView: View {
    let results: [StudyResult]
    
    var body: some View {
        List(results) { study in
            VStack(alignment: .leading) {
                Text(study.patientName ?? "Unknown")
                    .font(.headline)
                Text("ID: \(study.patientID ?? "N/A")")
                    .font(.subheadline)
                HStack {
                    Text(study.studyDate ?? "")
                    Spacer()
                    Text(study.modality ?? "")
                }
                .font(.caption)
            }
        }
    }
}

// Query at series level
func searchSeries(studyInstanceUID: String) async throws -> [SeriesResult] {
    let queryKeys = QueryKeys()
        .set(studyInstanceUID: studyInstanceUID)
    
    return try await client.findSeries(forStudy: studyInstanceUID, 
                                        matching: queryKeys)
}
```

**Key APIs:**
- `QueryService` - C-FIND operations
- `QueryKeys` - Build query attributes
- `StudyResult`, `SeriesResult`, `InstanceResult` - Type-safe results
- `DICOMClient.findStudies/findSeries/findInstances`

### 4.3 Study Retrieval

**Deliverables:**
- [ ] C-GET retrieve implementation
- [ ] C-MOVE retrieve implementation
- [ ] Progress display during download
- [ ] Local storage management
- [ ] Retrieve queue with status

**Implementation Pointers:**
```swift
// C-GET retrieval (simpler - no separate SCP needed)
func retrieveStudyWithGet(studyInstanceUID: String) async throws {
    let progress = try await client.getStudy(
        studyInstanceUID: studyInstanceUID,
        priority: .medium
    )
    
    // Process incoming images
    for try await event in progress {
        switch event {
        case .progress(let p):
            await MainActor.run {
                self.retrieveProgress = p
                self.statusMessage = "Retrieved \(p.completed)/\(p.total)"
            }
        case .instanceReceived(let data):
            // Process received DICOM data
            let dicomFile = try DICOMFile.read(from: data)
            await MainActor.run {
                self.receivedFiles.append(dicomFile)
            }
        case .completed(let result):
            await MainActor.run {
                self.statusMessage = "Completed: \(result.completed) images"
            }
        case .error(let error):
            throw error
        }
    }
}

// C-MOVE retrieval (requires local SCP running)
func retrieveStudyWithMove(studyInstanceUID: String, 
                           destinationAE: String) async throws {
    let progress = try await client.moveStudy(
        studyInstanceUID: studyInstanceUID,
        destinationAETitle: destinationAE,
        priority: .medium
    )
    
    for try await event in progress {
        switch event {
        case .progress(let p):
            await MainActor.run {
                self.retrieveProgress = p
            }
        case .completed(let result):
            print("Move completed: \(result.completed) sent")
        case .error(let error):
            throw error
        }
    }
}

// Progress UI
struct RetrieveProgressView: View {
    let progress: RetrieveProgress
    
    var body: some View {
        VStack {
            ProgressView(value: Double(progress.completed), 
                        total: Double(progress.total))
            Text("\(progress.completed) of \(progress.total) images")
            if progress.failed > 0 {
                Text("\(progress.failed) failed")
                    .foregroundColor(.red)
            }
        }
    }
}
```

**Key APIs:**
- `RetrieveService` - C-GET and C-MOVE operations
- `DICOMClient.getStudy/getSeries/getInstance` - C-GET convenience
- `DICOMClient.moveStudy/moveSeries/moveInstance` - C-MOVE convenience
- `RetrieveProgress` - Progress tracking

### 4.4 Local Storage SCP (for C-MOVE)

**Deliverables:**
- [ ] Local Storage SCP server
- [ ] Auto-start/stop with app
- [ ] Incoming file handler
- [ ] Storage directory configuration

**Implementation Pointers:**
```swift
// Start local Storage SCP
actor LocalStorageServer {
    private var server: DICOMStorageServer?
    private let configuration: StorageSCPConfiguration
    
    init(aeTitle: String, port: Int, storageDirectory: URL) {
        self.configuration = StorageSCPConfiguration(
            aeTitle: aeTitle,
            port: port,
            acceptedSOPClasses: CommonStorageSOPClasses.all,
            acceptedTransferSyntaxes: CommonTransferSyntaxes.all
        )
    }
    
    func start() async throws {
        let delegate = LocalStorageDelegate(directory: storageDirectory)
        server = DICOMStorageServer(
            configuration: configuration,
            delegate: delegate
        )
        try await server?.start()
    }
    
    func stop() async {
        await server?.stop()
    }
}

// Implement StorageDelegate
class LocalStorageDelegate: StorageDelegate {
    let directory: URL
    
    init(directory: URL) {
        self.directory = directory
    }
    
    func shouldAcceptAssociation(from info: AssociationInfo) -> Bool {
        // Accept all associations or implement whitelist
        return true
    }
    
    func willReceive(sopClassUID: String, sopInstanceUID: String) async -> Bool {
        // Accept all SOP Classes
        return true
    }
    
    func didReceive(file: ReceivedFile) async throws {
        // Save to disk
        let filename = "\(file.sopInstanceUID).dcm"
        let fileURL = directory.appendingPathComponent(filename)
        try file.dataSetData.write(to: fileURL)
        
        // Notify UI
        await MainActor.run {
            NotificationCenter.default.post(
                name: .newDICOMFileReceived,
                object: fileURL
            )
        }
    }
    
    func didFail(error: Error, for sopInstanceUID: String) {
        print("Failed to receive \(sopInstanceUID): \(error)")
    }
}
```

### 4.5 Error Handling and Retry

**Deliverables:**
- [ ] Network error display with recovery suggestions
- [ ] Automatic retry for transient failures
- [ ] Connection timeout handling
- [ ] Offline mode support

**Implementation Pointers:**
```swift
// Configure retry policy
let retryPolicy = RetryPolicy.exponentialBackoff(
    maxRetries: 3,
    baseDelay: .seconds(1),
    maxDelay: .seconds(30)
)

// Handle network errors with categories
func handleNetworkError(_ error: Error) {
    if let networkError = error as? DICOMNetworkError {
        switch networkError.category {
        case .transient:
            showRetryableError(networkError)
        case .permanent:
            showPermanentError(networkError)
        case .timeout:
            showTimeoutError(networkError)
        case .configuration:
            showConfigurationError(networkError)
        case .protocol:
            showProtocolError(networkError)
        case .resource:
            showResourceError(networkError)
        }
        
        // Show recovery suggestion
        if let suggestion = networkError.recoverySuggestion {
            showRecoverySuggestion(suggestion.description)
        }
    }
}

// Timeout configuration
let timeoutConfig = TimeoutConfiguration(
    connect: .seconds(10),
    read: .seconds(30),
    write: .seconds(30),
    operation: .minutes(5),
    association: .minutes(10)
)
```

### Phase 4 Acceptance Criteria

- [ ] Can connect to PACS servers with C-ECHO
- [ ] Patient/Study search returns accurate results
- [ ] C-GET successfully retrieves images to viewer
- [ ] C-MOVE successfully sends images to local SCP
- [ ] Progress reporting is accurate during retrieval
- [ ] Error handling provides actionable feedback
- [ ] TLS connections work with secure PACS

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
| 1 | 2-3 weeks | Basic file viewer with image display and metadata |
| 2 | 2-3 weeks | Image manipulation (window/level, pan, zoom, frames) |
| 3 | 2-3 weeks | Advanced viewing (measurements, tag browser, comparison) |
| 4 | 3-4 weeks | PACS connectivity (C-ECHO, C-FIND, C-GET, C-MOVE) |
| 5 | 2-3 weeks | Study management (database, import, organization) |
| 6 | 2 weeks | Platform-specific features (macOS, iOS, visionOS) |
| 7 | 1-2 weeks | Polish, documentation, testing |

**Total Estimated Duration**: 14-20 weeks

## Getting Started

1. Create a new Xcode project (App template, SwiftUI, Multi-platform)
2. Add DICOMKit as a Swift Package dependency
3. Follow Phase 1 setup instructions
4. Iterate through phases, testing after each phase
5. Use sample DICOM files for testing (available from public datasets)

## Resources

- [DICOMKit Repository](https://github.com/raster-image/DICOMKit)
- [DICOM Standard](https://www.dicomstandard.org/)
- [Sample DICOM Files](https://www.dicomlibrary.com/)
- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple visionOS Documentation](https://developer.apple.com/visionos/)
