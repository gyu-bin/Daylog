import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit

/// Native clipping checks cover older deployment targets without a frame timer.
final class PioCloudSceneHost: NSView {
    var hosted: CALayer?
    var visibilityChanged: ((Bool) -> Void)?
    override func layout() {
        super.layout(); hosted?.position = CGPoint(x: bounds.midX, y: bounds.midY); refreshVisibility()
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); observeWindow(); observeClips(); refreshVisibility() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); observeClips(); refreshVisibility() }
    override func viewDidHide() { super.viewDidHide(); refreshVisibility() }
    override func viewDidUnhide() { super.viewDidUnhide(); refreshVisibility() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    private func observeClips() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView {
                // NotificationCenter observes the clip without making this
                // descendant own its ancestor (clip -> document -> host).
                clip.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(clipChanged), name: NSView.boundsDidChangeNotification, object: clip)
            }
            ancestor = view.superview
        }
    }
    private func observeWindow() {
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
            if let window {
                NotificationCenter.default.addObserver(self, selector: #selector(clipChanged), name: name, object: window)
            }
        }
    }
    @objc private func clipChanged(_ notification: Notification) { refreshVisibility() }
    func refreshVisibility() {
        visibilityChanged?(window?.isVisible == true && window?.isMiniaturized == false
                           && window?.occlusionState.contains(.visible) == true && !isHiddenOrHasHiddenAncestor && !visibleRect.isEmpty && visibleRect.intersects(bounds))
    }
    deinit { NotificationCenter.default.removeObserver(self) }
}
#else
import UIKit

final class PioCloudSceneHost: UIView {
    var hosted: CALayer?
    var visibilityChanged: ((Bool) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    override func layoutSubviews() {
        super.layoutSubviews(); hosted?.position = CGPoint(x: bounds.midX, y: bounds.midY); refreshVisibility()
    }
    override func didMoveToWindow() { super.didMoveToWindow(); observeScrolls(); refreshVisibility() }
    override func didMoveToSuperview() { super.didMoveToSuperview(); observeScrolls(); refreshVisibility() }
    private func observeScrolls() {
        observations.removeAll()
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                observations.append(scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in self?.refreshVisibility() })
            }
            ancestor = view.superview
        }
    }
    func refreshVisibility() {
        guard let window, !bounds.isEmpty else { visibilityChanged?(false); return }
        var visible = convert(bounds, to: window).intersection(window.bounds)
        var ancestor: UIView? = self
        while let view = ancestor {
            if view.isHidden || view.alpha < 0.01 { visibilityChanged?(false); return }
            if view.clipsToBounds { visible = visible.intersection(view.convert(view.bounds, to: window)) }
            if visible.isNull || visible.isEmpty { visibilityChanged?(false); return }
            ancestor = view.superview
        }
        visibilityChanged?(true)
    }
}
#endif
