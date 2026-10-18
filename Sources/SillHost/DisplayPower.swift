import Foundation
import CoreGraphics
import IOKit.pwr_mgt

/// The Mac's display while devices are connected (docs/display-sleep-plan.md). A sleeping display is
/// not composited, so ScreenCaptureKit has nothing to give a device but black. While Keep display
/// awake (`HostConfig.keepDisplayAwake`) is on and a device is connected, the host holds the display
/// from idle sleep with one IOKit assertion, the kind a video player holds, and wakes a display that
/// is already asleep when a device connects or picks a source, as a key press would. The rule is
/// `DisplayPowerRule`, pure; the IOKit calls are `DisplayPower`'s. A synthetic host never touches
/// the display.
package struct DisplayPowerRule: Equatable, Sendable {
    /// What the hold does when who is connected or the setting changes: nothing, take the assertion,
    /// or release it.
    package enum HoldChange: Equatable, Sendable { case hold, release }

    /// The assertion wanted: the setting on and at least one device connected (home or remote).
    package static func wantsHold(enabled: Bool, devices: Int) -> Bool { enabled && devices > 0 }

    /// From `holding` to what is wanted; nil when nothing changes. Never on a synthetic host.
    package static func holdChange(enabled: Bool, devices: Int, holding: Bool, synthetic: Bool) -> HoldChange? {
        guard !synthetic else { return nil }
        let want = wantsHold(enabled: enabled, devices: devices)
        if want == holding { return nil }
        return want ? .hold : .release
    }

    /// Whether to wake the display now: it is asleep, the setting is on, not a synthetic host.
    package static func wakes(enabled: Bool, asleep: Bool, synthetic: Bool) -> Bool {
        !synthetic && enabled && asleep
    }

    /// How long `select` waits for a display it woke to light before capture starts, and how often it
    /// looks.
    package static let wakeWait: TimeInterval = 3
    package static let wakePoll: TimeInterval = 0.05

    /// The assertion's name, as `pmset -g assertions` lists it.
    package static let holdReason = "Sill is streaming to a device"

    // MARK: Words

    package static let heldLine = "Display: kept awake while a device is connected."
    package static let releasedLine = "Display: may sleep again (no device connected)."

    /// After a wake: how long the display took to light (nil: it had not lit within `wakeWait`), and
    /// whether this Mac is locked, which no device can undo.
    package static func wokeLine(lit: TimeInterval?, locked: Bool) -> String {
        var line = "Display: it was asleep; woke it for a device"
        if let lit {
            line += " (lit in \(String(format: "%.1f", lit)) s)."
        } else {
            line += ", but it had not lit \(Int(wakeWait)) s later."
        }
        if locked { line += " This Mac is locked: unlock it to see it from the device." }
        return line
    }

    /// The display is asleep when a device connects and the setting is off.
    package static let leftAsleepLine = "Display: asleep while a device is connected; Keep display awake is off, so it stays dark and the device sees nothing until it wakes."
}

/// The IOKit side: one assertion at most, and the wake. Main actor, as the coordinator is.
@MainActor
package final class DisplayPower {
    private(set) var enabled: Bool
    private let synthetic: Bool
    private var assertion: IOPMAssertionID = 0
    private(set) var holding = false
    private var devices = 0
    /// Said once while the display stays asleep with the setting off; said again after it lit.
    private var saidLeftAsleep = false

    package init(enabled: Bool, synthetic: Bool) {
        self.enabled = enabled
        self.synthetic = synthetic
    }

    /// Whether the main display is asleep now. A synthetic host never asks.
    package static var displayAsleep: Bool { CGDisplayIsAsleep(CGMainDisplayID()) != 0 }

    /// Who is connected changed (`StreamServer.onClientCountChanged`).
    package func devices(_ count: Int) {
        devices = count
        apply()
    }

    /// The setting changed (`StreamCoordinator.setTarget`, at once). Returns whether it moved.
    @discardableResult
    package func setEnabled(_ on: Bool) -> Bool {
        guard on != enabled else { return false }
        enabled = on
        apply()
        return true
    }

    /// Quit, and a signal: the assertion goes with the process anyway; released here so the line is
    /// printed and nothing outlives a staged shutdown.
    package func release() {
        devices = 0
        apply()
    }

    private func apply() {
        guard let change = DisplayPowerRule.holdChange(enabled: enabled, devices: devices, holding: holding, synthetic: synthetic) else { return }
        switch change {
        case .hold:
            var id: IOPMAssertionID = 0
            let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                     IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                     DisplayPowerRule.holdReason as CFString, &id)
            guard status == kIOReturnSuccess else {
                print("Display: could not hold it awake (IOKit \(status)).")
                return
            }
            assertion = id
            holding = true
            print(DisplayPowerRule.heldLine)
        case .release:
            IOPMAssertionRelease(assertion)
            assertion = 0
            holding = false
            print(DisplayPowerRule.releasedLine)
        }
    }

    /// A device connected or picked a source: wake a sleeping display. Returns whether a wake was
    /// asked for (the caller then waits with `waitUntilLit`). With the setting off, one line says why
    /// the device sees nothing.
    package func wakeIfAsleep() -> Bool {
        guard !synthetic, Self.displayAsleep else { saidLeftAsleep = false; return false }
        guard DisplayPowerRule.wakes(enabled: enabled, asleep: true, synthetic: synthetic) else {
            if !saidLeftAsleep { print(DisplayPowerRule.leftAsleepLine); saidLeftAsleep = true }
            return false
        }
        var id: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity(DisplayPowerRule.holdReason as CFString, kIOPMUserActiveLocal, &id)
        return true
    }

    /// After `wakeIfAsleep` said yes: waits until the display is lit, at most `wakeWait`, then prints
    /// the line (with whether this Mac is locked, which the device cannot undo).
    package func waitUntilLit(testHost: Bool) async {
        let start = CFAbsoluteTimeGetCurrent()
        var lit: TimeInterval?
        while CFAbsoluteTimeGetCurrent() - start < DisplayPowerRule.wakeWait {
            if !Self.displayAsleep { lit = CFAbsoluteTimeGetCurrent() - start; break }
            try? await Task.sleep(nanoseconds: UInt64(DisplayPowerRule.wakePoll * 1_000_000_000))
        }
        let locked = !SessionLock.shared.unlocked(testHost: testHost)
        print(DisplayPowerRule.wokeLine(lit: lit, locked: locked))
    }
}
