import UIKit

/// The Mac's menus from a secondary click (docs/menu-bar-plan.md §7.5, "A secondary click"): a
/// trackpad's two-finger click or a mouse's right button on the streamed window's thumbnail, or on
/// the top band of the picture (a window's title bar, the Desktop's menu bar), opens the Menus
/// button's pull-down where the click landed, with the same deferred elements (MacMenuElements).
/// Anywhere else in the picture a secondary click stays the Mac's own, a right-click there, which
/// is the app's contextual menu. Needs iOS 17.4 (`UIControl.performPrimaryAction`); before it the
/// click goes to the Mac as before.
enum MacMenuContextRule {
    /// The band at the top of the picture, in the device's points: a window's title bar is 28 Mac
    /// points at Aa 1× and the Desktop's menu bar 24, so 32 covers either at 1× and the upper part
    /// of a title bar at a larger scale. Pure.
    static let topBand: CGFloat = 32

    /// Whether a secondary click at `point` in a picture of `size` opens the menus: the Mac sent
    /// menus, the click is in the band, and iOS can open a menu from code.
    static func opensMenus(at point: CGPoint, in size: CGSize, hasMenus: Bool, canPresent: Bool = available) -> Bool {
        guard hasMenus, canPresent, size.width > 0, size.height > 0 else { return false }
        return point.x >= 0 && point.x <= size.width && point.y >= 0 && point.y < min(topBand, size.height)
    }

    static var available: Bool {
        if #available(iOS 17.4, *) { return true } else { return false }
    }
}

/// Opens the Mac's menus at a point of a view: a clear 2 × 2 pt `MacMenuTriggerButton` (the Menus
/// button's own, so the pull-down reports when it shows and goes) moved under the point and asked
/// for its primary action, which is its menu. The button takes no touch of its own.
final class MacMenuPopup {
    private let trigger = MacMenuTriggerButton(type: .custom)
    weak var client: StreamClient?
    var onOpen: () -> Void = {}
    var onClose: () -> Void = {}

    init() {
        trigger.showsMenuAsPrimaryAction = true
        trigger.preferredMenuElementOrder = .fixed      // the Mac's order whichever way it opens (MacMenuTrigger)
        trigger.backgroundColor = .clear
        // Interactive (UIKit presents no menu from a control that is not), 2 pt wide, so it takes
        // no touch of its own that matters.
        trigger.isUserInteractionEnabled = true
        trigger.isAccessibilityElement = false
        trigger.frame = CGRect(x: -10, y: -10, width: 2, height: 2)
        trigger.onOpenChange = { [weak self] open in
            DispatchQueue.main.async { if open { self?.onOpen() } else { self?.onClose() } }
        }
    }

    /// Puts the trigger into `view` (once).
    func attach(to view: UIView) {
        if trigger.superview !== view { view.addSubview(trigger) }
    }

    /// Whether a click now would open menus: the Mac sent some, and iOS can open them from code.
    var canPresent: Bool { MacMenuContextRule.available && (client?.menus.hasMenus ?? false) }

    /// Opens the menus at `point`, in the view the trigger was attached to. False when it cannot
    /// (no menus, before iOS 17.4, not on screen): the caller then treats the click as the Mac's.
    @discardableResult
    func present(at point: CGPoint) -> Bool {
        guard #available(iOS 17.4, *) else { log("not on this iOS (17.4 needed)"); return false }
        guard let client else { log("no client"); return false }
        guard client.menus.hasMenus else { log("the Mac sent no menus"); return false }
        guard trigger.window != nil else { log("the trigger is not on screen"); return false }
        trigger.menu = UIMenu(children: MacMenuElements.topMenus(client, barIdentifiers: false))
        trigger.frame = CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)
        trigger.superview?.bringSubviewToFront(trigger)
        log("opening the pull-down at \(Int(point.x)),\(Int(point.y))")
        trigger.performPrimaryAction()
        return true
    }

    private func log(_ what: String) {
        #if DEBUG
        print("menus: secondary click: \(what)")
        #endif
    }
}
