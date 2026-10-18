# iOS 27.1-only code, and how it is switched off on Xcode 27.0

The iPhone Duo's hinge support uses APIs that exist only in the iOS 27.1 SDK (`View.onHingeChange`,
`DeviceHingeContext`, `GeometryProxy.reservedRegions(kind: .division, …)`). With Xcode 27.0 (the
App Store's) the project does not compile unless that code is left out.

It is left out automatically, not by hand: the Xcode project (`iOSClient/Sill.xcodeproj`, both the
Debug and Release configurations) defines the Swift compilation condition `SILL_NO_HINGE_SDK` only
when the SDK is 27.0:

    SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphoneos27.0*]        = SILL_NO_HINGE_SDK $(inherited)
    SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator27.0*] = SILL_NO_HINGE_SDK $(inherited)

and `iOSClient/DuoPostureReader.swift` wraps the three uses in `#if !SILL_NO_HINGE_SDK … #endif`:

| Where in DuoPostureReader.swift | What |
|---|---|
| `DuoPostureReader.body` | `.onHingeChange { … }`, the hinge into the environment |
| `extension DuoPosture.Hinge { init(_ context: DeviceHingeContext) }` | the hinge's status read |
| `DuoPosture.read`, case `.reservedRegions` | `geo.reservedRegions(kind: .division, options: .includeInactive)`, the fold |

With the code left out the hinge reads `unknown` everywhere, which is what every device without a
hinge reports anyway: nothing changes on an iPad or a plain iPhone.

## To bring it back

Nothing to edit. Build with Xcode 27.1 or later (the SDK is then `iphoneos27.1`, the condition is
not set, and the code compiles in). `Scripts/release-ios.sh` already refuses an Xcode before 27.1,
so an App Store build can never ship without it.

To remove this mechanism altogether once nobody builds with 27.0 any more: delete the two
`SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=…]` lines from each configuration in
`project.pbxproj`, the `#if !SILL_NO_HINGE_SDK` / `#else` / `#endif` lines around the three places
above, the paragraph that explains it at the top of DuoPostureReader.swift, and this file.
