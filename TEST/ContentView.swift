//
//  ContentView.swift
//  TEST
//
//  Created by Mahiro on 2025/12/24.
//

import SwiftUI
import Vision
import FoundationModels
import Foundation

struct ContentView: View {
    @State private var isShowingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var recognizedText: String = ""
    @State private var isProcessing = false
    @State private var showSourceActionSheet = false

    @State private var summarizedText: String = ""
    @State private var isSummarizing = false
    @State private var summarizeError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Group {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                        Text("画像がありません")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                HStack {
                    Button {
                        showSourceActionSheet = true
                    } label: {
                        Label("画像を選ぶ", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .confirmationDialog("画像の取得方法", isPresented: $showSourceActionSheet, titleVisibility: .visible) {
                        Button("写真を撮る") {
                            imagePickerSource = .camera
                            isShowingImagePicker = true
                        }
                        Button("ライブラリから選ぶ") {
                            imagePickerSource = .photoLibrary
                            isShowingImagePicker = true
                        }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) == false {
                            // If camera not available, show info
                            Text("カメラは利用できません")
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                    
                    Button {
                        Task { await performOCR() }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Label("OCR 実行", systemImage: "text.viewfinder")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedImage == nil || isProcessing)
                }
                
                HStack(spacing: 12) {
                    Button {
                        Task { await summarizeWithFoundationModels() }
                    } label: {
                        if isSummarizing {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Label("要約", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(recognizedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty || isSummarizing)

                    Button(role: .destructive) {
                        summarizedText = ""
                        recognizedText = ""
                        summarizeError = nil
                    } label: {
                        Label("クリア", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                // AI Chat Button
                HStack {
                    NavigationLink {
                        ChatView(contextText: recognizedText)
                    } label: {
                        Label("AIとチャットする", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(recognizedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("抽出テキスト")
                            .font(.headline)
                        Spacer()
                        if !recognizedText.isEmpty {
                            Button {
                                UIPasteboard.general.string = recognizedText
                            } label: {
                                Label("コピー", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    ScrollView {
                        Text(recognizedText.isEmpty ? "ここに認識結果が表示されます" : recognizedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }

                    Divider().padding(.vertical, 4)

                    HStack {
                        Text("要約")
                            .font(.headline)
                        Spacer()
                        if !summarizedText.isEmpty {
                            Button {
                                UIPasteboard.general.string = summarizedText
                            } label: {
                                Label("コピー", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    if let summarizeError {
                        Text("要約エラー: \(summarizeError)")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    ScrollView {
                        Text(summarizedText.isEmpty ? "ここに要約結果が表示されます" : summarizedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Smart Scanner AI")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(sourceType: imagePickerSource, selectedImage: $selectedImage)
            }
        }
    }
    
    // MARK: - OCR with Vision
    private func performOCR() async {
        guard let uiImage = selectedImage, let cgImage = uiImage.cgImage else { return }
        recognizedText = ""
        isProcessing = true
        defer { isProcessing = false }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let strings: [String] = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            recognizedText = strings.joined(separator: "\n")
        } catch {
            recognizedText = "OCRでエラーが発生しました: \(error.localizedDescription)"
        }
    }

    // MARK: - On-device Summarization with Foundation Models
    private func summarizeWithFoundationModels() async {
        let input = recognizedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isSummarizing = true
        summarizeError = nil
        summarizedText = ""
        defer { isSummarizing = false }

        // Guard for platform availability
        if #available(iOS 18.0, *) {
            do {
                // Prepare prompt
                let prompt = """
                以下のテキストを日本語で簡潔に要約してください。重要なポイントを箇条書きで3〜5項目にまとめてください。必要なら英語も含まれて構いません。

                ---
                \(input)
                ---
                出力は純粋なテキストのみでお願いします。
                """

                // Initialize a text generator using FoundationModels
                // Choose a default on-device capable model identifier when available.
                // Fallback to a generic initializer if specific presets are unavailable.
                #if canImport(FoundationModels)
                // Use the LanguageModelSession API provided by FoundationModels
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                self.summarizedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                #else
                // If FoundationModels isn't linked, provide a helpful error
                throw NSError(domain: "Summarization", code: 1, userInfo: [NSLocalizedDescriptionKey: "FoundationModels フレームワークが利用できません。ターゲットのリンク設定と iOS バージョンを確認してください。"])
                #endif
            } catch {
                self.summarizeError = error.localizedDescription
            }
        } else {
            // iOS version too low
            self.summarizeError = "この機能には iOS 18 以降が必要です。"
        }
    }
}

// MARK: - UIKit Image Picker bridge
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
