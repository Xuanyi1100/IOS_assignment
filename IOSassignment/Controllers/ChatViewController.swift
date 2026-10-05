import UIKit

/// Chat screen: type a prompt, press Send, watch the engine answer.
///
/// Storyboard wiring (human step): set the scene's Custom Class to
/// `ChatViewController`, connect the outlets below, and connect the text field's
/// delegate and the button's Touch Up Inside to `sendTapped`.
final class ChatViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var promptTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var responseTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var engineLabel: UILabel!

    private var engine: InferenceEngine = EngineResolver.current()

    /// The running generation. Non-nil while the engine is working; cancelling it
    /// is what the Stop button does.
    private var generationTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("chat.title", value: "Chat", comment: "Chat screen title")
        promptTextField.delegate = self
        responseTextView.isEditable = false
        // Spinner is only visible while the engine is working.
        activityIndicator.hidesWhenStopped = true
        responseTextView.text = NSLocalizedString("chat.placeholder",
                                                  value: "Ask something. The answer appears here.",
                                                  comment: "Empty-state text in the response area")

        // Tapping the background dismisses the keyboard.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        setGenerating(false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Settings may have changed the engine while this screen was hidden.
        engine = EngineResolver.current()
        engineLabel.text = String(format: NSLocalizedString("chat.engine", value: "Engine: %@",
                                                            comment: "Label showing the active engine"),
                                  engine.displayName)
    }

    #if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Test hook for automated runs (Debug builds only): launching with
        // `-debug.autoPrompt "text"` sends that prompt without anyone typing it.
        if let prompt = UserDefaults.standard.string(forKey: "debug.autoPrompt"),
           generationTask == nil, (promptTextField.text ?? "").isEmpty {
            promptTextField.text = prompt
            send()
        }
    }
    #endif

    // MARK: - Actions

    /// Send when idle, Stop while generating (one button, two roles).
    @IBAction func sendTapped(_ sender: UIButton) {
        if generationTask != nil {
            generationTask?.cancel()
            return
        }
        send()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // Return key sends, like a messaging app.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if generationTask == nil { send() }
        return true
    }

    // MARK: - Generation

    private func send() {
        let prompt = (promptTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            showError(InferenceError.emptyPrompt)
            return
        }
        guard engine.isAvailable else {
            showError(InferenceError.engineUnavailable(reason: engine.displayName))
            return
        }

        responseTextView.text = ""
        setGenerating(true)

        let engine = self.engine
        let streaming = AppSettings.streamingEnabled
        let maxWords = AppSettings.maxWords

        // This Task body runs on the main actor, but the engine does its work in its own
        // task off the main thread; we only await its results here and update the UI.
        generationTask = Task {
            do {
                // Real engines download/load their model here; progress text goes into the
                // response area. The callback may arrive on any thread, so hop to main for UI.
                try await engine.prepare { [weak textView = responseTextView] message in
                    DispatchQueue.main.async { textView?.text = message }
                }
                responseTextView.text = ""

                if streaming {
                    for try await piece in engine.stream(prompt: prompt) {
                        responseTextView.text += piece
                        // Real models stream tokens, not words, so count words in the text.
                        let words = responseTextView.text.split(whereSeparator: { $0.isWhitespace }).count
                        if words >= maxWords { break } // leaving the loop cancels the stream
                    }
                } else {
                    let full = try await engine.generate(prompt: prompt)
                    responseTextView.text = Self.truncate(full, toWords: maxWords)
                }
            } catch {
                showError(error)
            }
            generationTask = nil
            setGenerating(false)
        }
    }

    /// Cuts text to at most `limit` words.
    private static func truncate(_ text: String, toWords limit: Int) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        return words.count <= limit ? text : words.prefix(limit).joined(separator: " ") + "…"
    }

    // MARK: - UI state

    /// Swaps the Send button into a Stop button and shows the spinner while busy.
    private func setGenerating(_ busy: Bool) {
        if busy { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        let titleKey = busy
            ? NSLocalizedString("chat.stop", value: "Stop", comment: "Button title while generating")
            : NSLocalizedString("chat.send", value: "Send", comment: "Send button title")
        sendButton.setTitle(titleKey, for: .normal)
        promptTextField.isEnabled = !busy
    }

    /// Every failure that can reach the user is shown as an alert that says what went wrong.
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: NSLocalizedString("error.title", value: "Something went wrong", comment: "Alert title"),
            message: error.localizedDescription,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.ok", value: "OK", comment: "OK button"),
                                      style: .default))
        present(alert, animated: true)
    }
}
