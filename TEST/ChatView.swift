//
//  ChatView.swift
//  TEST
//
//  Created by Mahiro on 2025/12/25.
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ChatView: View {
    let contextText: String
    #if canImport(FoundationModels)
    @State private var session: LanguageModelSession?
    #else
    @State private var session: Any? // Placeholder for missing type
    #endif
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?
    
    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            Text("ドキュメントについて質問してみましょう。\n例: 「この文書の要点は？」")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 40)
                        }
                        
                        ForEach(messages) {
                            message in
                            MessageBubble(message: message)
                        }
                        
                        if isThinking {
                            HStack {
                                ProgressView()
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Circle())
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages) {
                    if let lastId = messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            HStack(alignment: .bottom) {
                TextField("質問を入力...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isThinking || session == nil)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking || session == nil)
            }
            .padding()
        }
        .navigationTitle("AIチャット")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await initializeSession()
        }
    }
    
    private func initializeSession() async {
        // Only initialize if not already done
        if session != nil { return }
        
        if #available(iOS 18.0, *) {
            #if canImport(FoundationModels)
            let newSession = LanguageModelSession()
            self.session = newSession
            
            isThinking = true
            // Inject context as the first invisible turn
            let initialPrompt = """
            以下のテキストは、ユーザーがOCRで読み取ったドキュメントの内容です。
            このテキストの内容を前提知識として、ユーザーからの質問に答えてください。
            わからないことは正直に「わかりません」と答えてください。
            
            ---
            \(contextText)
            ---
            
            準備ができたら、ユーザーへの挨拶は不要で、単に「OK」とだけ答えてください。
            """
            
            do {
                _ = try await newSession.respond(to: initialPrompt)
                isThinking = false
            } catch {
                isThinking = false
                errorMessage = "セッションの開始に失敗しました: \(error.localizedDescription)"
            }
            #else
            errorMessage = "FoundationModels フレームワークが見つかりません。"
            #endif
        } else {
            errorMessage = "この機能には iOS 18.0 以降が必要です。"
        }
    }
    
    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        
        inputText = ""
        errorMessage = nil
        messages.append(ChatMessage(text: question, isUser: true))
        isThinking = true
        
        Task {
            if #available(iOS 18.0, *) {
                #if canImport(FoundationModels)
                guard let currentSession = session else { return }
                do {
                    let response = try await currentSession.respond(to: question)
                    let answer = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        messages.append(ChatMessage(text: answer, isUser: false))
                        isThinking = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                        isThinking = false
                    }
                }
                #endif
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatView.ChatMessage
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    // 吹き出しのしっぽのような形状にするための角丸調整
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        )
                    )
            } else {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .padding(.top, 8)
                
                Text(message.text)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 0
                        )
                    )
                    .textSelection(.enabled)
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(contextText: "これはテスト用のテキストです。OCRで読み取られた内容がここに入ります。")
    }
}
