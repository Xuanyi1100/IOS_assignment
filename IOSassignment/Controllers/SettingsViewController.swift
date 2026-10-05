import UIKit

/// Settings screen: four control types (switch, slider, segmented control, stepper).
///
/// Storyboard wiring (human step): set Custom Class to `SettingsViewController`,
/// connect the outlets, and connect each control's Value Changed to its action.
final class SettingsViewController: UIViewController {

    @IBOutlet weak var streamingSwitch: UISwitch!
    @IBOutlet weak var temperatureSlider: UISlider!
    @IBOutlet weak var temperatureValueLabel: UILabel!
    @IBOutlet weak var engineSegmentedControl: UISegmentedControl!
    @IBOutlet weak var maxWordsStepper: UIStepper!
    @IBOutlet weak var maxWordsValueLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("settings.title", value: "Settings", comment: "Settings screen title")

        // Configure ranges in code so they can't drift from what the logic expects.
        temperatureSlider.minimumValue = 0
        temperatureSlider.maximumValue = 1
        maxWordsStepper.minimumValue = 10
        maxWordsStepper.maximumValue = 200
        maxWordsStepper.stepValue = 10

        // The "On-device" segment only works when the LiteRT package is linked. Without it the
        // option is greyed out and any stale saved choice is reset, so the UI never claims an
        // engine that is not actually running.
        #if !canImport(LiteRTFoundation)
        engineSegmentedControl.setEnabled(false, forSegmentAt: 1)
        AppSettings.engineIndex = 0
        #endif

        // Load saved values into the controls.
        streamingSwitch.isOn = AppSettings.streamingEnabled
        temperatureSlider.value = AppSettings.temperature
        engineSegmentedControl.selectedSegmentIndex = AppSettings.engineIndex
        maxWordsStepper.value = Double(AppSettings.maxWords)
        refreshLabels()
    }

    // MARK: - Actions

    @IBAction func streamingChanged(_ sender: UISwitch) {
        AppSettings.streamingEnabled = sender.isOn
    }

    @IBAction func temperatureChanged(_ sender: UISlider) {
        AppSettings.temperature = sender.value
        refreshLabels()
    }

    @IBAction func engineChanged(_ sender: UISegmentedControl) {
        AppSettings.engineIndex = sender.selectedSegmentIndex
    }

    @IBAction func maxWordsChanged(_ sender: UIStepper) {
        AppSettings.maxWords = Int(sender.value)
        refreshLabels()
    }

    private func refreshLabels() {
        temperatureValueLabel.text = String(format: "%.2f", temperatureSlider.value)
        maxWordsValueLabel.text = String(format: NSLocalizedString("settings.maxWords", value: "%d words",
                                                                   comment: "Reply length limit"),
                                         Int(maxWordsStepper.value))
    }
}
