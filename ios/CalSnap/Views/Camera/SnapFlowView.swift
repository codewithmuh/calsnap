import PhotosUI
import SwiftUI

/// The moneyshot: photo -> Claude -> calories appear -> save -> ring animates.
/// Works in guest mode too — analysis is anonymous; saving goes local or to the account.
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
    @State private var imageData: Data?
    @State private var note = ""
    @State private var mealType: MealType = .current
    @State private var analysis: Analysis?
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
                    setImage(captured)
                    stage = .preview
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        setImage(ui)
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
        if let analysis {
            ScrollView {
                VStack(spacing: 18) {
                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text(analysis.foodName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("\(analysis.calories)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                    + Text(" kcal").font(.title3).foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        macroPill("Protein", analysis.protein, .blue)
                        macroPill("Carbs", analysis.carbs, .orange)
                        macroPill("Fat", analysis.fat, .purple)
                    }

                    Text("Confidence: \(Int(analysis.confidence * 100))%")
                        .font(.caption).foregroundStyle(.secondary)

                    mealTypePicker

                    Button {
                        save(analysis)
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

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Which meal is this?")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    let selected = mealType == type
                    Button {
                        mealType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon).font(.title3)
                            Text(type.label).font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selected ? AnyShapeStyle(.tint)
                                     : AnyShapeStyle(Color(.secondarySystemBackground)),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
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

    private func setImage(_ ui: UIImage) {
        image = ui
        imageData = ui.jpegData(compressionQuality: 0.7)
    }

    private func analyze() {
        guard let imageData else { return }
        errorMessage = nil
        stage = .analyzing
        Task {
            do {
                analysis = try await APIClient.shared.analyze(imageData: imageData, note: note)
                stage = .result
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                stage = .preview
            }
        }
    }

    private func save(_ analysis: Analysis) {
        Task {
            await meals.addAnalyzed(analysis, mealType: mealType, imageData: imageData, note: note)
            dismiss()
        }
    }

    private func reset() {
        image = nil
        imageData = nil
        analysis = nil
        note = ""
        mealType = .current
        photoItem = nil
        errorMessage = nil
        stage = .choose
    }
}
