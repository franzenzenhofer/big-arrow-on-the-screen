import BigArrowCore
import Testing

@Suite("Settings pane titles")
struct SettingsPaneTests {
    @Test("The Accessibility permission list is named as macOS shows it")
    func accessibilityTitle() {
        #expect(SettingsPane.accessibilityTitle(macOSMajor: 26) == "Accessibility")
        #expect(SettingsPane.accessibilityTitle(macOSMajor: 27) == "Device Control and Data Access")
    }
}
