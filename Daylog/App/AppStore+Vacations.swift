import Foundation

extension AppStore {
    func vacations(on day: Day) -> [VacationPeriod] {
        vacationPeriods.filter { $0.contains(day) }
    }

    func isVacation(on day: Day) -> Bool {
        vacationPeriods.contains { $0.contains(day) }
    }

    @discardableResult
    func saveVacation(id: UUID? = nil, start: Day, end: Day, memo: String = "") -> Bool {
        flush()
        guard !context.hasChanges else { return false }
        let succeeded = perform {
            try VacationService(context: context, deviceID: deviceID).save(id: id, start: start, end: end, memo: memo)
        }
        reloadStats()
        return succeeded
    }

    @discardableResult
    func removeVacation(_ period: VacationPeriod) -> Bool {
        flush()
        guard !context.hasChanges else { return false }
        let succeeded = perform {
            try VacationService(context: context, deviceID: deviceID).remove(period)
        }
        reloadStats()
        return succeeded
    }
}
