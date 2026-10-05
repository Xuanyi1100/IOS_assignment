import UIKit

/// About screen: app version, which engine is active, credits.
///
/// Storyboard wiring (human step): set Custom Class to `AboutViewController` and
/// connect the three labels.
final class AboutViewController: UIViewController {

    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var engineStatusLabel: UILabel!
    @IBOutlet weak var creditsLabel: UILabel!
    /// Shows the RAM the OS reports for this device; decides which models can safely load.
    @IBOutlet weak var ramLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("about.title", value: "About", comment: "About screen title")

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        versionLabel.text = String(format: NSLocalizedString("about.version", value: "Version %@",
                                                             comment: "App version; %@ is the number"),
                                   version)
        let ram = ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory),
                                            countStyle: .memory)
        ramLabel.text = String(format: NSLocalizedString("about.ram", value: "Device memory: %@",
                                                         comment: "Physical RAM; %@ is e.g. 5.7 GB"),
                               ram)
        creditsLabel.text = NSLocalizedString("about.credits",
                                              value: "PocketLLM — an on-device language model demo for PROG3230.",
                                              comment: "Credits line")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh every time: the engine can change in Settings.
        let engine = EngineResolver.current()
        engineStatusLabel.text = String(format: NSLocalizedString("about.engine", value: "Active engine: %@",
                                                                  comment: "Shows the active engine"),
                                        engine.displayName)
    }
}
