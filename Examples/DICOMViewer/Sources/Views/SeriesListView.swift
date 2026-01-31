import SwiftUI

/// List view showing series in a study
struct SeriesListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: SeriesListViewModel
    
    let study: StudyItem
    
    init(study: StudyItem) {
        self.study = study
        _viewModel = StateObject(wrappedValue: SeriesListViewModel(studyInstanceUID: study.id))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading series...")
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Error Loading Series", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await viewModel.loadSeries(using: appState.pacsService)
                        }
                    }
                }
            } else if viewModel.series.isEmpty {
                ContentUnavailableView {
                    Label("No Series Found", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("This study contains no series")
                }
            } else {
                List(viewModel.series) { series in
                    NavigationLink(destination: ImageViewerView(series: series).environmentObject(appState)) {
                        SeriesRowView(series: series)
                    }
                }
            }
        }
        .navigationTitle(study.displayPatientName)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(study.displayPatientName)
                        .font(.headline)
                    Text(study.displayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await viewModel.loadSeries(using: appState.pacsService)
        }
    }
}

/// Row view for a series
struct SeriesRowView: View {
    let series: SeriesItem
    
    var body: some View {
        HStack {
            // Series icon based on modality
            Image(systemName: iconForModality(series.modality))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let number = series.seriesNumber {
                        Text("Series \(number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let modality = series.modality {
                        Text(modality)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(series.displayDescription)
                    .font(.headline)
                
                if let bodyPart = series.bodyPart {
                    Text(bodyPart)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let count = series.numberOfInstances {
                    Text("\(count) images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func iconForModality(_ modality: String?) -> String {
        switch modality {
        case "CT": return "cube.transparent"
        case "MR": return "brain.head.profile"
        case "CR", "DX": return "photo"
        case "US": return "waveform"
        case "NM", "PT": return "atom"
        case "XA": return "heart"
        case "MG": return "photo.artframe"
        default: return "photo.on.rectangle"
        }
    }
}

/// View model for series list
@MainActor
class SeriesListViewModel: ObservableObject {
    let studyInstanceUID: String
    
    @Published var series: [SeriesItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(studyInstanceUID: String) {
        self.studyInstanceUID = studyInstanceUID
    }
    
    func loadSeries(using service: PACSService) async {
        isLoading = true
        errorMessage = nil
        
        do {
            series = try await service.findSeries(forStudy: studyInstanceUID)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SeriesListView(study: StudyItem(
            id: "1.2.3.4.5",
            patientName: "DOE^JOHN",
            patientID: "12345",
            studyDate: "20240115",
            studyTime: "120000",
            studyDescription: "CT CHEST WITH CONTRAST",
            modalities: "CT",
            accessionNumber: "ACC123",
            numberOfSeries: 3,
            numberOfInstances: 150
        ))
        .environmentObject(AppState())
    }
}
