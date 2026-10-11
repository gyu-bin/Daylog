import Foundation

extension AppStore {
    /// Do not hide the editor if saving its current contents fails.
    @discardableResult
    func setMealsEnabled(_ enabled: Bool, preferences: DevicePreferences) -> Bool {
        if !enabled {
            guard perform({
                try recordPendingEdits()
                try context.save()
            }) else { return false }
        }
        if !enabled { reloadStats() }
        preferences.setMealsEnabled(enabled)
        section = preferences.safeSelection(section)
        return true
    }
}
