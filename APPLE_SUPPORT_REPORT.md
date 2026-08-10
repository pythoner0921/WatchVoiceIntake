# App Store distribution export fails for ALL distribution methods, across 3 independent build environments

## Summary

A newly-approved Apple Developer Program account (Individual) cannot export an archive for **any** account-based distribution method — not App Store, not Ad Hoc, not Development, not Enterprise. This has been reproduced identically across three completely independent build environments, including Apple's own Xcode Cloud, ruling out any local/CI configuration issue.

## Account details

- Team: Zhaozhen Tong
- Team ID: (see App Store Connect → Membership)
- Program type: Individual
- Enrolled: 2026-08-10 (same day as this issue)

## Exact error

```
error: exportArchive exportOptionsPlist error for key "method" expected one {} but found app-store
** EXPORT FAILED **
```

Underlying log (`IDEDistribution.verbose.log`) shows **every single distribution method rejected**:

```
Rejected distribution method <IDEDistributionMethodiOSAppStoreDistribution> because it doesn't support distributing archive
Rejected distribution method <IDEDistributionMethodiOSAdHoc> because it doesn't support distributing archive
Rejected distribution method <IDEDistributionMethodDevelopmentSigned> because it doesn't support distributing archive
Rejected distribution method <IDEDistributionMethodiOSEnterprise> because it doesn't support distributing archive
... (every method for iOS/watchOS/tvOS/visionOS/Mac, all rejected identically)
Available distribution methods: {(
    <IDEDistributionMethodSaveBuiltProducts>,
    <IDEDistributionMethodExportArchive>
)}
```

Only the two account-independent local export options remain available. This is true even for **Development** distribution, which per Apple's own documentation should be the least restrictive method and shouldn't require anything beyond a registered device.

## What's been verified correct (via App Store Connect API + openssl, not just visual inspection)

- Two App Store Connect provisioning profiles, both `IOS_APP_STORE` type, `ACTIVE` state, valid through 2027
- One `Apple Distribution` certificate, `DISTRIBUTION` type, valid through 2027
- Certificate chain verified cryptographically correct (WWDR G3 intermediate's Subject Key Identifier matches the certificate's Authority Key Identifier byte-for-byte)
- Both Bundle IDs registered correctly, App record exists in App Store Connect with matching Bundle ID
- Archive itself codesigns successfully with the correct identity and provisioning profile for each target (confirmed in build logs: `Signing Identity: "Apple Distribution: Zhaozhen Tong"`, `Provisioning Profile: "WatchVoiceIntake AppStore"`)
- `CFBundleShortVersionString`/`CFBundleVersion` present and valid in both targets' Info.plist

## Reproduced identically across 3 independent environments

1. **GitHub Actions, raw `xcodebuild archive` + `xcodebuild -exportArchive`** — manual signing, Xcode 16.4 and Xcode 26.3 (latest available on the runner) — same error both versions
2. **GitHub Actions, fastlane `build_app`** — same underlying `xcodebuild` call, same error
3. **Xcode Cloud** (Apple's own hosted CI, using cloud-managed signing, no manually-created certs/profiles involved at all) — same "doesn't support distributing archive" rejection for every method, including Development

Environment #3 is the strongest evidence this isn't a local/CI configuration problem — it's Apple's own infrastructure hitting the same wall on the same account.

## What's been ruled out (with evidence, not assumption)

- Manual vs. automatic code signing style — both tried
- Xcode version (16.4 vs 26.3) — both fail identically
- Tool (raw xcodebuild vs fastlane vs Xcode Cloud) — all fail identically
- `method` value in ExportOptions.plist (`app-store` vs `app-store-connect`) — both rejected identically
- Certificate trust chain — cryptographically verified complete and correct
- Missing WWDR/Root CA intermediate certificates — added, no change
- API key role (App Manager vs Admin) — tried both
- `SKIP_INSTALL` build setting on the main app target — added, no change
- Bundle version fields — present and valid
- ~3 hour wait for possible account backend propagation — no change

## Request

Please investigate why this Individual account, approved same-day, cannot export an archive for ANY signed distribution method (including Development), across both third-party CI and Apple's own Xcode Cloud. This appears to be an account-level eligibility flag that hasn't been set correctly on Apple's backend, not a client-side configuration issue.
