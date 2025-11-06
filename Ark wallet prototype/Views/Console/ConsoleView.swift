//
//  ConsoleView.swift
//  Ark wallet prototype
//
//  Created by Christoph on 11/6/25.
//

import SwiftUI

struct ConsoleEntry: Identifiable {
    let id = UUID()
    let command: String
    let result: String
    let isError: Bool
    let timestamp: Date
}

struct ConsoleView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var commandInput: String = ""
    @State private var history: [ConsoleEntry] = []
    @State private var isExecuting: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Developer Console")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    history.removeAll()
                }
                .disabled(history.isEmpty)
            }
            .padding()
            
            Divider()
            
            // History Display
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if history.isEmpty {
                            Text("Type a command below to get started...")
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        
                        ForEach(history) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                // Command
                                HStack(spacing: 4) {
                                    Text(">")
                                        .foregroundStyle(.secondary)
                                    Text(entry.command)
                                        .foregroundStyle(.primary)
                                }
                                .font(.system(.body, design: .monospaced))
                                
                                // Result
                                Text(entry.result)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(entry.isError ? .red : .secondary)
                                    .textSelection(.enabled)
                                    .padding(.leading, 12)
                            }
                            .padding(.horizontal)
                            .id(entry.id)
                        }
                        
                        // Show executing indicator
                        if isExecuting {
                            HStack(spacing: 4) {
                                Text(">")
                                    .foregroundStyle(.secondary)
                                Text(commandInput)
                                    .foregroundStyle(.primary)
                            }
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal)
                            
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Executing...")
                                    .foregroundStyle(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(.leading, 12)
                            .padding(.horizontal)
                            .id("executing")
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: history.count) { _, _ in
                    // Auto-scroll to bottom when new entry is added
                    if let lastEntry = history.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isExecuting) { _, newValue in
                    // Auto-scroll when execution starts
                    if newValue {
                        withAnimation {
                            proxy.scrollTo("executing", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Command Input
            HStack(spacing: 8) {
                Text(">")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
                
                TextField("Type command here...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .disabled(isExecuting)
                    .onSubmit {
                        executeCommand()
                    }
                
                Button(action: executeCommand) {
                    Image(systemName: "arrow.right.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .disabled(commandInput.isEmpty || isExecuting)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func executeCommand() {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !command.isEmpty else { return }
        guard !isExecuting else { return }
        
        isExecuting = true
        
        Task {
            do {
                let result = try await walletManager.executeCustomCommand(command)
                
                await MainActor.run {
                    history.append(ConsoleEntry(
                        command: command,
                        result: result.isEmpty ? "(empty response)" : result,
                        isError: false,
                        timestamp: Date()
                    ))
                    commandInput = ""
                    isExecuting = false
                    isInputFocused = true
                }
            } catch {
                await MainActor.run {
                    history.append(ConsoleEntry(
                        command: command,
                        result: "Error: \(error.localizedDescription)",
                        isError: true,
                        timestamp: Date()
                    ))
                    commandInput = ""
                    isExecuting = false
                    isInputFocused = true
                }
            }
        }
    }
}

#Preview {
    ConsoleView()
        .environment(WalletManager(useMock: true))
        .frame(width: 600, height: 400)
}
