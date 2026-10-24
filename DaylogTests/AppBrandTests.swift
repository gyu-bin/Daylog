import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Daylog

@MainActor
struct AppBrandTests {
    @Test func appMetadataAndPresentationUseExactBrandCase() {
        #expect(AppBrand.name == "RoutiMori")
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == AppBrand.name)
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String == AppBrand.name)
    }

    @Test func cachedRemoteCopyIsNormalizedWithoutRewritingItsPayload() {
        var settings = MobileUISettings.builtIn
        settings.text[.onboardingNotificationBody] = "설정한 시간에 Daylog가 알려드려요."
        #expect(settings.string(.onboardingNotificationBody) == "설정한 시간에 RoutiMori가 알려드려요.")
        #expect(settings.text[.onboardingNotificationBody] == "설정한 시간에 Daylog가 알려드려요.")
        #expect(AppBrand.displayCopy("Routimori · 루티모리") == "RoutiMori · RoutiMori")
        #expect(settings.string(.dashboardGreeting) == MobileUISettings.TextKey.dashboardGreeting.builtIn)
    }

    @Test func visibleNotificationRenameRefreshesContentButPreservesRequestIdentity() {
        let routine = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let plan = PlannedNotification(routineID: routine, dateKey: "2026-10-23", title: "물 마시기",
            timeLabel: "09:30", groupTitle: "아침", year: 2026, month: 10, day: 23, hour: 9, minute: 30)
        #expect(plan.notificationTitle == "RoutiMori · 루틴 시간이에요")
        #expect(plan.id == "routine.00000000-0000-0000-0000-000000000123.2026-10-23")
        #expect(plan.signature != "물 마시기|아침|9:30")
        #expect(plan.signature.hasSuffix(plan.notificationTitle))
    }

    @Test func rebrandingCannotRenamePurchaseOrSharedStorageProtocols() {
        #expect(WidgetBridge.appGroupID == "group.com.mungyubin.daylog")
        #expect(UTType.daylogTemplate.identifier == "com.mungyubin.daylog.template")
        #expect(TemplateFile.fileExtension == "daylogtemplate")
        #expect(PioProductRegistry.verifiedBundleID == "com.mungyubin.daylog.ios")
        #expect(PioProductRegistry.productIDs == [
            "outfit.cherryblossom", "outfit.summer", "outfit.autumn", "outfit.winter",
            "outfit.halloween", "outfit.christmas", "outfit.hanbok", "outfit.cafe",
            "outfit.student", "outfit.workout", "outfit.rainy", "outfit.pajamas", "outfit.space"
        ])
    }
}
