import PhotosUI
import SwiftUI

/// The moneyshot: photo -> Claude -> calories appear -> save -> ring animates.
struct SnapFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MealStore.self) private var meals

    enum Stage {
        case choose
        case preview
        case analyzing
        case result
    }

    @State private var stage: Stage = .choose
    @State private var image: UIImage?
    @State private var note = ""
    @State private var analyzed: Meal?
    @State private var errorMessage: String?

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch stage {
                case .choose:    chooseStage
                case .preview:   previewStage
                case .analyzing: analyzingStage
                case .result:    resultStage
                }
            }
            .padding()
            .navigationTitle("Snap a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { captured in
                    image = captured
                    stage = .preview
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        image = ui
                        stage = .preview
                    }
                }
            }
        }
    }

    // MARK: - Stages

    private var chooseStage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Take or pick a photo of your meal.")
                .foregroundStyle(.secondary)

            if CameraPicker.isCameraAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
    }

    private var previewStage: some View {
        VStack(spacing: 16) {
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            TextField("Add a note (optional, e.g. “large bowl”)", text: $note)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: analyze) {
                Label("Analyze with Claude", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            Button("Retake") { reset() }
                .font(.subheadline)
            Spacer()
        }
    }

    private var analyzingStage: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.tint, lineWidth: 2))
            }
            ProgressView()
                .controlSize(.large)
            Text("Claude is analyzing your meal…")
                .font(.headline)
            Text("Identifying food and estimating macros")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var resultStage: some View {
        if let analyzed {
            ScrollView {
                VStack(spacing: 18) {
                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text(analyzed.foodName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("\(analyzed.calories)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                    + Text(" kcal").font(.title3).foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        macroPill("Protein", analyzed.protein, .blue)
                        macroPill("Carbs", analyzed.carbs, .orange)
                        macroPill("Fat", analyzed.fat, .purple)
                    }

                    Text("Confidence: \(Int(analyzed.confidence * 100))%")
                        .font(.caption).foregroundStyle(.secondary)

                    Button {
                        meals.add(analyzed)
                        dismiss()
                    } label: {
                        Label("Save to today", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding()
                            .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    Button("Retake") { reset() }
                        .font(.subheadline)
                }
                .padding(.vertical)
            }
        }
    }

    private func macroPill(_ name: String, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(grams)g").font(.headline).foregroundStyle(color)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func analyze() {
        guard let image, let data = image.jpegData(compressionQuality: 0.7) else { return }
        errorMessage = nil
        stage = .analyzing
        Task {
            do {
                let meal = try await APIClient.shared.createMeal(imageData: data, note: note)
                analyzed = meal
                stage = .result
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .preview
            }
        }
    }

    private func reset() {
        image = nil
        analyzed = nil
        note = ""
        photoItem = nil
        errorMessage = nil
        stage = .choose
    }
}
