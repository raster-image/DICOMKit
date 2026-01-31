# DICOM Viewer Example

A sample SwiftUI application demonstrating how to use DICOMKit to build a DICOM Viewer that connects to a PACS server.

## Overview

This example application shows how to:

- **Connect to a PACS server** using C-ECHO for connectivity testing
- **Browse studies** using C-FIND queries
- **View series** within a study
- **Display images** with pixel data rendering and window/level adjustments

## Requirements

- **Xcode 16+** with Swift 6.2
- **macOS 14.0+** or **iOS 17.0+** or **visionOS 1.0+**
- A DICOM-compliant PACS server (e.g., Orthanc, dcm4chee)

## Building the Example

### Option 1: Using Xcode

1. Open the DICOMKit package in Xcode:
   ```bash
   cd DICOMKit
   open Package.swift
   ```

2. Select the `DICOMViewer` scheme in the scheme selector

3. Choose your target device (Mac, iPhone, or Vision Pro simulator)

4. Build and run (⌘R)

### Option 2: Using Swift Package Manager (macOS only)

```bash
cd DICOMKit
swift build --target DICOMViewer
```

Note: SwiftUI apps require a GUI environment and cannot be run from the command line.

## Configuration

### PACS Connection Settings

The app uses the following default configuration:

| Setting | Default Value |
|---------|---------------|
| Host | localhost |
| Port | 11112 |
| Calling AE | DICOM_VIEWER |
| Called AE | ORTHANC |
| Timeout | 30 seconds |

You can modify these settings in the app's Settings view (⌘, on macOS).

### Using with Orthanc

[Orthanc](https://www.orthanc-server.com/) is a free, open-source DICOM server that's perfect for development and testing.

#### Quick Start with Docker

```bash
docker run -p 4242:4242 -p 8042:8042 jodogne/orthanc
```

Then update the app settings:
- Host: `localhost`
- Port: `4242`
- Called AE: `ORTHANC`

#### Uploading Test Data

1. Access the Orthanc web interface at http://localhost:8042
2. Upload DICOM files using the web UI
3. Use the DICOM Viewer app to browse and view the images

## Features

### Study Browser

- Search for studies by patient name or ID
- View study details (date, modality, description)
- See series and instance counts

### Advanced Search

- Filter by patient name, ID, accession number
- Date range filtering
- Modality filtering (CT, MR, CR, etc.)

### Image Viewer

- Full DICOM image display
- Window/level adjustments
- Image navigation (slider and buttons)
- Zoom and pan gestures
- Reset to default window settings

## Architecture

```
DICOMViewer/
├── Sources/
│   ├── App/
│   │   └── DICOMViewerApp.swift      # App entry point
│   ├── Models/
│   │   ├── PACSConfiguration.swift    # PACS settings
│   │   └── ViewModels.swift           # Data models
│   ├── Services/
│   │   └── PACSService.swift          # PACS communication
│   └── Views/
│       ├── ContentView.swift          # Main navigation
│       ├── SettingsView.swift         # Configuration UI
│       ├── StudyBrowserView.swift     # Study search/list
│       ├── SeriesListView.swift       # Series browser
│       ├── QueryView.swift            # Advanced search
│       └── ImageViewerView.swift      # Image display
```

## DICOMKit APIs Used

This example demonstrates the following DICOMKit APIs:

### Verification (C-ECHO)

```swift
let success = try await DICOMVerificationService.echo(
    host: "localhost",
    port: 11112,
    callingAE: "DICOM_VIEWER",
    calledAE: "ORTHANC"
)
```

### Query (C-FIND)

```swift
// Find studies
let studies = try await DICOMQueryService.findStudies(
    host: host,
    port: port,
    callingAE: callingAE,
    calledAE: calledAE,
    matching: QueryKeys.defaultStudyKeys().patientName("*SMITH*")
)

// Find series in a study
let series = try await DICOMQueryService.findSeries(
    host: host,
    port: port,
    callingAE: callingAE,
    calledAE: calledAE,
    forStudy: studyInstanceUID
)

// Find instances in a series
let instances = try await DICOMQueryService.findInstances(
    host: host,
    port: port,
    callingAE: callingAE,
    calledAE: calledAE,
    forStudy: studyInstanceUID,
    forSeries: seriesInstanceUID
)
```

### Retrieve (C-GET)

```swift
let client = DICOMClient(configuration: clientConfig)

for try await file in try await client.get(
    studyInstanceUID: studyUID,
    seriesInstanceUID: seriesUID,
    sopInstanceUID: instanceUID
) {
    // Process each DICOM file
}
```

### Image Rendering

```swift
// Extract pixel data
guard let pixelData = dicomFile.pixelData() else { return }

// Create renderer
let renderer = PixelDataRenderer(
    pixelData: pixelData,
    paletteColorLUT: dicomFile.paletteColorLUT()
)

// Render with window settings
let window = WindowSettings(center: 40, width: 400)
let cgImage = renderer.renderMonochromeFrame(0, window: window)
```

## Troubleshooting

### Connection Failed

- Verify the PACS server is running
- Check the host, port, and AE titles are correct
- Ensure network connectivity (firewall rules)
- Try the C-ECHO test in the sidebar

### No Studies Found

- Verify there is data on the PACS server
- Check your search criteria (try wildcard: `*`)
- Some PACS require exact AE title matching

### Images Not Displaying

- Not all transfer syntaxes may be supported
- Check the console for error messages
- Verify the PACS supports C-GET (some only support C-MOVE)

## License

This example is part of DICOMKit and is provided under the MIT License.
