import Foundation
import IOKit.hid
import LidFoldCore

/// Reads the hinge angle from Apple's lid sensor over IOKit HID.
///
/// The sensor's usage page and report layout are undocumented, which is why support
/// varies between models. The device is opened read-only and never seized, so the
/// system keeps using it as normal.
public final class HIDLidAngleSource: LidAngleSource {
    private enum Match {
        static let vendorID = 0x05ac
        static let productID = 0x8104
        static let usagePage = 0x20
        static let usage = 0x8a
    }

    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    public private(set) var availability: SensorAvailability

    public init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        availability = .unavailable(reason: "No readable lid sensor")

        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: Match.vendorID,
            kIOHIDProductIDKey: Match.productID,
            kIOHIDPrimaryUsagePageKey: Match.usagePage,
            kIOHIDPrimaryUsageKey: Match.usage
        ] as CFDictionary)

        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            availability = .unavailable(reason: "HID access failed (\(opened))")
            return
        }

        let candidates = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        for candidate in candidates {
            guard IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
            device = candidate
            if let angle = readAngle() {
                availability = .available(detail: "Lid sensor connected: \(angle.readout)")
                return
            }
            IOHIDDeviceClose(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
            device = nil
        }

        availability = .unavailable(
            reason: candidates.isEmpty
                ? "No lid sensor on this Mac"
                : "Found \(candidates.count) matching device(s), none readable"
        )
    }

    public func readAngle() -> LidAngle? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: LidAngleReport.byteCount)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, LidAngleReport.reportID, &report, &length)
        guard result == kIOReturnSuccess else { return nil }
        return LidAngleReport.decode(report, length: length)
    }

    deinit {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
