import SwiftUI
import DICOMKit
import DICOMCore
import CoreGraphics

/// Main image viewer for displaying DICOM images
struct ImageViewerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ImageViewerViewModel
    
    let series: SeriesItem
    
    init(series: SeriesItem) {
        self.series = series
        _viewModel = StateObject(wrappedValue: ImageViewerViewModel(
            studyInstanceUID: series.studyInstanceUID,
            seriesInstanceUID: series.id
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.currentImage == nil {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Loading images...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                } else if let error = viewModel.errorMessage, viewModel.currentImage == nil {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Error loading images")
                            .foregroundColor(.white)
                            .padding(.top)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if let image = viewModel.currentImage {
                    // Image display
                    ImageDisplayView(
                        cgImage: image,
                        windowCenter: $viewModel.windowCenter,
                        windowWidth: $viewModel.windowWidth
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No image available")
                            .foregroundColor(.gray)
                    }
                }
                
                // Overlay controls
                VStack {
                    // Top bar with info
                    HStack {
                        VStack(alignment: .leading) {
                            Text(series.displayDescription)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalImages)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        // Window/Level display
                        VStack(alignment: .trailing) {
                            Text("W: \(Int(viewModel.windowWidth))")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("L: \(Int(viewModel.windowCenter))")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 12) {
                        // Image slider
                        if viewModel.totalImages > 1 {
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.currentIndex) },
                                    set: { viewModel.goToImage(Int($0)) }
                                ),
                                in: 0...max(0, Double(viewModel.totalImages - 1)),
                                step: 1
                            )
                            .tint(.white)
                            .padding(.horizontal)
                        }
                        
                        // Navigation buttons
                        HStack(spacing: 40) {
                            Button(action: viewModel.previousImage) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .disabled(!viewModel.canGoBack)
                            .opacity(viewModel.canGoBack ? 1 : 0.3)
                            
                            Button(action: viewModel.resetWindowLevel) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: viewModel.nextImage) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .disabled(!viewModel.canGoForward)
                            .opacity(viewModel.canGoForward ? 1 : 0.3)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Loading indicator for image transitions
                if viewModel.isLoading && viewModel.currentImage != nil {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInstances(using: appState.pacsService)
        }
    }
}

/// View for displaying and interacting with the image
struct ImageDisplayView: View {
    let cgImage: CGImage
    @Binding var windowCenter: Double
    @Binding var windowWidth: Double
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            #if os(iOS) || os(visionOS)
            Image(uiImage: UIImage(cgImage: cgImage))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1 {
                                    withAnimation {
                                        scale = 1
                                        lastScale = 1
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                )
            #elseif os(macOS)
            Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
            #endif
        }
    }
}

/// View model for image viewer
@MainActor
class ImageViewerViewModel: ObservableObject {
    let studyInstanceUID: String
    let seriesInstanceUID: String
    
    @Published var instances: [InstanceItem] = []
    @Published var currentIndex: Int = 0
    @Published var currentImage: CGImage?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Window/level settings - defaults are soft tissue CT preset
    // These will be updated from DICOM file metadata when available
    private static let defaultSoftTissueCenter: Double = 40
    private static let defaultSoftTissueWidth: Double = 400
    
    @Published var windowCenter: Double = defaultSoftTissueCenter
    @Published var windowWidth: Double = defaultSoftTissueWidth
    
    private var defaultWindowCenter: Double = defaultSoftTissueCenter
    private var defaultWindowWidth: Double = defaultSoftTissueWidth
    private var hasSetDefaultsFromDICOM: Bool = false
    
    private var loadedFiles: [String: DICOMFile] = [:]
    private var pacsService: PACSService?
    
    var totalImages: Int { instances.count }
    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < totalImages - 1 }
    
    init(studyInstanceUID: String, seriesInstanceUID: String) {
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
    }
    
    func loadInstances(using service: PACSService) async {
        self.pacsService = service
        isLoading = true
        errorMessage = nil
        
        do {
            instances = try await service.findInstances(
                forStudy: studyInstanceUID,
                forSeries: seriesInstanceUID
            )
            
            if !instances.isEmpty {
                await loadImage(at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func previousImage() {
        guard canGoBack else { return }
        goToImage(currentIndex - 1)
    }
    
    func nextImage() {
        guard canGoForward else { return }
        goToImage(currentIndex + 1)
    }
    
    func goToImage(_ index: Int) {
        guard index >= 0 && index < totalImages else { return }
        currentIndex = index
        
        Task {
            await loadImage(at: index)
        }
    }
    
    func resetWindowLevel() {
        windowCenter = defaultWindowCenter
        windowWidth = defaultWindowWidth
        
        // Re-render with default window settings
        Task {
            await renderCurrentImage()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadImage(at index: Int) async {
        guard index < instances.count else { return }
        
        let instance = instances[index]
        let sopUID = instance.id
        
        // Check if already loaded
        if let file = loadedFiles[sopUID] {
            await renderImage(from: file)
            return
        }
        
        // Retrieve from PACS
        guard let service = pacsService else { return }
        
        isLoading = true
        
        do {
            let file = try await service.retrieveInstance(
                studyInstanceUID: studyInstanceUID,
                seriesInstanceUID: seriesInstanceUID,
                sopInstanceUID: sopUID
            )
            
            loadedFiles[sopUID] = file
            await renderImage(from: file)
            
            // Preload adjacent images
            Task {
                await preloadAdjacentImages()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func renderCurrentImage() async {
        guard currentIndex < instances.count else { return }
        let instance = instances[currentIndex]
        
        if let file = loadedFiles[instance.id] {
            await renderImage(from: file)
        }
    }
    
    private func renderImage(from file: DICOMFile) async {
        guard let pixelData = file.pixelData() else {
            errorMessage = "Unable to extract pixel data"
            return
        }
        
        // Extract window settings from DICOM if available (only set once per series)
        if !hasSetDefaultsFromDICOM,
           let center = file.dataSet.floatArray(for: .windowCenter)?.first,
           let width = file.dataSet.floatArray(for: .windowWidth)?.first {
            defaultWindowCenter = Double(center)
            defaultWindowWidth = Double(width)
            windowCenter = defaultWindowCenter
            windowWidth = defaultWindowWidth
            hasSetDefaultsFromDICOM = true
        }
        
        let renderer = PixelDataRenderer(
            pixelData: pixelData,
            paletteColorLUT: file.paletteColorLUT()
        )
        
        let window = WindowSettings(center: windowCenter, width: max(1, windowWidth))
        
        if pixelData.descriptor.photometricInterpretation.isMonochrome {
            currentImage = renderer.renderMonochromeFrame(0, window: window)
        } else {
            currentImage = renderer.renderFrame(0)
        }
    }
    
    private func preloadAdjacentImages() async {
        guard let service = pacsService else { return }
        
        let indicesToPreload = [currentIndex - 1, currentIndex + 1, currentIndex + 2]
            .filter { $0 >= 0 && $0 < totalImages }
        
        for index in indicesToPreload {
            let instance = instances[index]
            guard loadedFiles[instance.id] == nil else { continue }
            
            do {
                let file = try await service.retrieveInstance(
                    studyInstanceUID: studyInstanceUID,
                    seriesInstanceUID: seriesInstanceUID,
                    sopInstanceUID: instance.id
                )
                loadedFiles[instance.id] = file
            } catch {
                // Silently ignore preload failures
            }
        }
    }
}

#Preview {
    ImageViewerView(series: SeriesItem(
        id: "1.2.3.4.5.6",
        studyInstanceUID: "1.2.3.4.5",
        seriesNumber: 1,
        modality: "CT",
        seriesDescription: "CT Chest",
        numberOfInstances: 100,
        bodyPart: "CHEST"
    ))
    .environmentObject(AppState())
}
