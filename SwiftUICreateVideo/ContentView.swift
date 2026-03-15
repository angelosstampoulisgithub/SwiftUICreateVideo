//
//  ContentView.swift
//  SwiftUICreateVideo
//
//  Created by Angelos Staboulis on 14/3/26.
//
import SwiftUI
import PhotosUI
import AVFoundation
import AVKit

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var durationPerImage: Double = 1.0
    @State private var selectedMusic: URL?
    @State private var videoSize: VideoSize = .portrait
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var statusMessage = ""
    @State private var generatedVideoURL: URL?
    @State private var showPicker = false
    @State private var generator = VideoGenerator()
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            HStack(spacing: 5) {
                
                // LEFT PANEL — IMAGES
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Spacer()
                        Text("🎬 Video Generator")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    Button("Select Images") {
                        showPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.3))
                    .foregroundColor(.white)
                    .sheet(isPresented: $showPicker) {
                        PhotoPickerView { imgs in
                            self.images = imgs
                        }
                    }
                    
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 12) {
                            ForEach(images, id: \.self) { img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 4)
                                    .padding(.horizontal, 4)
                            }
                        }
                        if !images.isEmpty{
                            Button("Create Video") {
                                Task { await createVideoFlow() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        if isProcessing {
                            VStack(alignment: .leading) {
                                ProgressView(value: progress)
                                    .progressViewStyle(.linear)
                                    .tint(.white)
                                Text("Processing…")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        if let url = generatedVideoURL {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Preview")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                
                                VideoPlayer(player: AVPlayer(url: url))
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 8)
                            }
                        }
                        
                        Text(statusMessage)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                }
                .padding()
                .frame(maxWidth: 350)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(radius: 10)
                
                
                
                Spacer()
            }
            
            .padding()
        }
        .onChange(of: selectedItems) { newItems in
            Task { await loadImages(from: newItems) }
        }
    }
    
    
    // MARK: - PICK MUSIC
    func pickMusic() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
    }
    
    // MARK: - LOAD IMAGES
    func loadImages(from items: [PhotosPickerItem]) async {
        let loadedImages: [UIImage] = await withTaskGroup(of: UIImage?.self) { group in
            
            for item in items {
                group.addTask {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        return img
                    }
                    return nil
                }
            }
            
            var results: [UIImage] = []
            for await result in group {
                if let img = result {
                    results.append(img)
                }
            }
            return results
        }
        
        await MainActor.run {
            self.images = loadedImages
            self.selectedItems = []
        }
    }
    
    // MARK: - CREATE VIDEO FLOW
    func createVideoFlow() async {
        guard !images.isEmpty else { return }
        isProcessing = true
        progress = 0
        statusMessage = "Creating video..."
        
        let url = videoOutputURL()
        
        do {
            try await generator.createAdvancedVideo(
                images: images,
                outputURL: url,
                durationPerImage: durationPerImage,
                size: videoSize.size,
                musicURL: selectedMusic,
                progress: { value in
                    DispatchQueue.main.async {
                        self.progress = value
                    }
                }
            )
            await MainActor.run {
                self.generatedVideoURL = url
                statusMessage = "Saved video to: \(url.lastPathComponent)"
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    // MARK: - OUTPUT URL
    func videoOutputURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("output_video.mp4")
    }
}

// MARK: - VIDEO SIZE ENUM
enum VideoSize {
    case portrait, landscape, square
    
    var size: CGSize {
        switch self {
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

