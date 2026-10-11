#if os(iOS)
import AppIntents

// iOS 17-compatible app-process routing. Never add this app-only conformance to the extension.
// https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
extension ToggleRoutineIntent: ForegroundContinuableIntent {}
#endif
