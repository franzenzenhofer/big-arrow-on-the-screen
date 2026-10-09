/// Titles of System Settings panes that changed between macOS versions, so messages name the
/// pane a human actually sees. Verified in docs/research/2026-10-09-system-settings-deep-links.md.
public enum SettingsPane {
    /// macOS 27 renamed the Accessibility permission list under Privacy & Security.
    public static func accessibilityTitle(macOSMajor: Int) -> String {
        macOSMajor >= 27 ? "Device Control and Data Access" : "Accessibility"
    }
}
