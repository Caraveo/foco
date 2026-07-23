import Foundation
import Security

@MainActor
final class XAIWritingService: ObservableObject {
    static let shared = XAIWritingService()

    @Published var autocompleteEnabled: Bool {
        didSet { UserDefaults.standard.set(autocompleteEnabled, forKey: Self.enabledKey) }
    }
    @Published var apiKey: String {
        didSet { Keychain.store(apiKey, account: Self.keyAccount) }
    }

    private static let enabledKey = "xai.inlinePrediction.enabled"
    private static let keyAccount = "xai.api-key"
    private let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!
    private let autocompletePrompt = "You are an invisible fiction autocomplete engine. Predict only the next 3–12 words. Preserve the author’s tense, POV, voice, punctuation, and current sentence rhythm. Do not explain. Do not add a new plot point. Do not output quotes, labels, or markdown. If no confident continuation exists, return an empty response."

    private init() {
        autocompleteEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? false
        apiKey = Keychain.value(account: Self.keyAccount) ?? ""
    }

    func streamAutocomplete(context: String, writingContext: String, onDelta: @escaping @MainActor (String) -> Void) async throws {
        let payload: [String: Any] = [
            "model": "grok-4.20-0309-non-reasoning",
            "stream": true,
            "max_tokens": 32,
            "messages": [
                ["role": "system", "content": autocompletePrompt],
                ["role": "user", "content": "Page writing context (follow this when relevant):\\n\(writingContext.prefix(1_200))\\n\\nContinue this manuscript exactly at the cursor. Return only the continuation.\\n\\n\(context)"]
            ]
        ]
        var request = try makeRequest(payload)
        request.timeoutInterval = 25
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validate(response)
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let value = String(line.dropFirst(6))
            guard value != "[DONE]", let data = value.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }
            onDelta(content)
        }
    }

    func polish(_ selection: String, style: PolishStyle, writingContext: String) async throws -> String {
        let payload: [String: Any] = [
            "model": "grok-4.20-0309-non-reasoning",
            "stream": false,
            "messages": [
                ["role": "system", "content": "You are a precise fiction editor. Return only a revised version of the selected text. Preserve its meaning, POV, tense, and facts. Do not explain your changes."],
                ["role": "user", "content": "Page writing context:\\n\(writingContext.prefix(1_200))\\n\\nRevise this selection to be \(style.instruction):\\n\\n\(selection)"]
            ]
        ]
        let (data, response) = try await URLSession.shared.data(for: makeRequest(payload))
        try validate(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        return (choices?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
    }

    private func makeRequest(_ payload: [String: Any]) throws -> URLRequest {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw XAIError.missingKey }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else { throw XAIError.requestFailed }
    }
}

enum PolishStyle: String, CaseIterable, Identifiable {
    case clearer = "Clearer", tense = "More Tense", literary = "More Literary", spare = "More Spare"
    var id: String { rawValue }
    var instruction: String { rawValue.lowercased() }
}

enum XAIError: LocalizedError { case missingKey, requestFailed
    var errorDescription: String? { self == .missingKey ? "Add an xAI API key in Settings to use writing tools." : "xAI could not complete the request." }
}

@MainActor
final class XAIInlinePredictor {
    private var task: Task<Void, Never>?
    private(set) var requestID = 0
    private(set) var suggestion = ""

    func schedule(text: String, cursor: Int, writingContext: String, update: @escaping (String) -> Void) {
        cancel()
        guard XAIWritingService.shared.autocompleteEnabled else { return }
        let source = text as NSString
        let prefix = source.substring(to: min(cursor, source.length))
        let context = prefix.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).suffix(250).joined(separator: " ")
        guard !context.isEmpty else { return }
        requestID += 1
        let id = requestID
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, self?.requestID == id else { return }
            var received = ""
            do {
                try await XAIWritingService.shared.streamAutocomplete(context: context, writingContext: writingContext) { delta in
                    guard let self, self.requestID == id, !Task.isCancelled else { return }
                    received = Self.limitWords(received + delta)
                    self.suggestion = received
                    update(received)
                }
            } catch { }
        }
    }

    func cancel() {
        requestID += 1
        task?.cancel()
        task = nil
        suggestion = ""
    }

    private static func limitWords(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).prefix(12).joined(separator: " ")
    }
}

private enum Keychain {
    static func value(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.foco", kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func store(_ value: String, account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.foco", kSecAttrAccount as String: account]
        let data = value.data(using: .utf8) ?? Data()
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            SecItemAdd(query.merging([kSecValueData as String: data]) { _, new in new } as CFDictionary, nil)
        }
    }
}
