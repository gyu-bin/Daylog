import Foundation

/// 루틴의 예정 시간. 저장소에는 "07:30" 같은 글자로 들어 있다(표시용이고, 알림을 예약하지 않는다).
/// 예전에 자유롭게 적은 글자("아침 먹고" 등)는 시간으로 읽히지 않을 수 있다.
enum TimeLabel {
    /// 자정부터의 분. "7:30", "07:30"처럼 읽을 수 있을 때만.
    static func minutes(_ label: String) -> Int? {
        let parts = label.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    static func label(minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// 오늘 날짜의 그 시각. 시간 선택 컨트롤에 넣을 값.
    static func date(_ label: String, calendar: Calendar = .current) -> Date? {
        minutes(label).flatMap { calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: .now) }
    }

    static func label(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return label(minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}
