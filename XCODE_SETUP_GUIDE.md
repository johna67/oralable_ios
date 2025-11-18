# Xcode Configuration Guide: Adding Dentist App Target

This guide will walk you through adding the Oralable for Dentists app as a new target in your Xcode project.

## Prerequisites

- Xcode 15.0 or later
- OralableApp.xcodeproj already set up
- All dentist app files created in `OralableForDentists/` directory

## Part 1: Add New App Target

### Step 1: Open Project in Xcode

```bash
open OralableApp/OralableApp.xcodeproj
```

### Step 2: Create New Target

1. In Xcode, select the project in the navigator (blue icon at top)
2. Click the **+** button at the bottom of the targets list
3. Select **iOS** → **Application** → **App**
4. Click **Next**

### Step 3: Configure Target

Fill in the following details:

- **Product Name**: `OralableForDentists`
- **Team**: Select your development team
- **Organization Identifier**: `com.jacdental`
- **Bundle Identifier**: `com.jacdental.oralable.dentist` (should auto-fill)
- **Interface**: **SwiftUI**
- **Language**: **Swift**
- **Include Tests**: ✓ (checked)

Click **Finish**

Xcode will create:
- `OralableForDentists` group in navigator
- `OralableForDentistsTests` group
- `OralableForDentistsUITests` group

### Step 4: Delete Auto-Generated Files

Xcode created default template files we don't need. **Delete these files** (Move to Trash):

1. Right-click and delete:
   - `OralableForDentists/OralableForDentistsApp.swift`
   - `OralableForDentists/ContentView.swift`
   - `OralableForDentists/Assets.xcassets`
   - `OralableForDentists/Preview Content` folder

### Step 5: Add Dentist App Files

1. **Select all dentist app source files**:
   - In Finder, navigate to: `OralableForDentists/OralableForDentists/`
   - Select all `.swift` files and subdirectories:
     - `Managers/` (4 files)
     - `ViewModels/` (3 files)
     - `Views/` (5 files)
     - `OralableForDentists.swift`

2. **Drag into Xcode**:
   - Drag these files/folders into the `OralableForDentists` group in Xcode
   - In the dialog that appears:
     - ✓ **Copy items if needed** (UNCHECK - files are already in place)
     - ✓ **Create groups** (selected)
     - ✓ **Add to targets**: Check `OralableForDentists` ONLY

3. **Verify structure** in Xcode navigator:
```
OralableForDentists/
├── Managers/
│   ├── DentistSubscriptionManager.swift
│   ├── DentistDataManager.swift
│   ├── DentistAuthenticationManager.swift
│   └── DentistAppDependencies.swift
├── ViewModels/
│   ├── PatientListViewModel.swift
│   ├── AddPatientViewModel.swift
│   └── DentistSettingsViewModel.swift
├── Views/
│   ├── PatientListView.swift
│   ├── AddPatientView.swift
│   ├── PatientDetailView.swift
│   ├── DentistSettingsView.swift
│   └── UpgradePromptView.swift
└── OralableForDentists.swift
```

### Step 6: Configure Info.plist

1. In Xcode, select **OralableForDentists** target
2. Go to **Info** tab
3. Click the **Custom iOS Target Properties** dropdown
4. Click **+** to add entries (or find and modify existing):

Update these keys:
- `Bundle display name`: `Oralable for Dentists`
- `Bundle identifier`: `com.jacdental.oralable.dentist`
- `Bundle version string (short)`: `1.0.0`
- `Bundle version`: `1`

Or simply:
1. In Project Navigator, find `OralableForDentists` folder
2. Delete the auto-generated `Info.plist` if it exists
3. Drag your prepared `OralableForDentists/OralableForDentists/Info.plist` into the target
4. In target settings → Build Settings → search "Info.plist File"
5. Set path to: `OralableForDentists/OralableForDentists/Info.plist`

### Step 7: Configure Entitlements

1. In Xcode, select **OralableForDentists** target
2. Go to **Signing & Capabilities** tab
3. Set your Team
4. Check that `OralableForDentists.entitlements` is recognized

Or manually:
1. Drag your `OralableForDentists/OralableForDentists/OralableForDentists.entitlements` into Xcode
2. Target settings → Build Settings → search "Code Signing Entitlements"
3. Set to: `OralableForDentists/OralableForDentists/OralableForDentists.entitlements`

---

## Part 2: Share Common Files Between Targets

Some files need to be available to BOTH apps.

### Step 1: Add DesignSystem to Dentist Target

1. In Project Navigator, navigate to:
   - `OralableApp/OralableApp/Managers/DesignSystem/`

2. Select these files:
   - `DesignSystem.swift`
   - `ColorPalette.swift` (if exists)
   - `Typography.swift` (if exists)
   - Any other DesignSystem-related files

3. In Xcode **File Inspector** (right panel):
   - Check **Target Membership** for both:
     - ✓ OralableApp
     - ✓ OralableForDentists

### Step 2: Add Logger to Dentist Target

1. Navigate to: `OralableApp/OralableApp/Managers/`
2. Select: `Logger.swift`
3. In **File Inspector**:
   - ✓ OralableApp
   - ✓ OralableForDentists

### Step 3: Add LoggingService to Dentist Target

1. Navigate to: `OralableApp/OralableApp/Models/Devices/`
2. Select: `LoggingService.swift`
3. In **File Inspector**:
   - ✓ OralableApp
   - ✓ OralableForDentists

### Step 4: Remove Placeholder Logger

1. Open `OralableForDentists/Managers/DentistAppDependencies.swift`
2. Find the placeholder `Logger` class at the bottom
3. Delete lines that define the placeholder:
```swift
// MARK: - Placeholder Logger (will use shared Logger from patient app)

class Logger {
    static let shared = Logger()

    func info(_ message: String) {
        print("[INFO] \(message)")
    }

    func error(_ message: String) {
        print("[ERROR] \(message)")
    }

    func warning(_ message: String) {
        print("[WARNING] \(message)")
    }
}
```

### Step 5: Add Assets (if needed)

If you have shared assets:
1. Either share `OralableApp/Assets.xcassets` (check both target memberships)
2. Or create a separate `Assets.xcassets` for dentist app with:
   - App icon
   - Launch screen images
   - Any dentist-specific assets

---

## Part 3: Configure Capabilities

### Step 1: Sign in with Apple

1. Select **OralableForDentists** target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Sign in with Apple**

### Step 2: CloudKit

1. Click **+ Capability**
2. Add **iCloud**
3. Check **CloudKit**
4. Under "Containers":
   - Click **+**
   - Enter: `iCloud.com.jacdental.oralable.shared`
   - Or select from existing if available

### Step 3: In-App Purchase

1. Click **+ Capability**
2. Add **In-App Purchase**

### Step 4: App Groups (Optional)

1. Click **+ Capability**
2. Add **App Groups**
3. Click **+**
4. Enter: `group.com.jacdental.oralable`

### Step 5: Push Notifications

1. Click **+ Capability**
2. Add **Push Notifications**

---

## Part 4: Build Settings

### Step 1: Verify Build Settings

1. Select **OralableForDentists** target
2. Go to **Build Settings** tab
3. Search for and verify:

- **Product Name**: `OralableForDentists`
- **Product Bundle Identifier**: `com.jacdental.oralable.dentist`
- **Deployment Target**: iOS 17.0 (or your minimum)
- **Swift Language Version**: Swift 5

### Step 2: Set Deployment Info

1. Select **OralableForDentists** target
2. **General** tab
3. Under **Deployment Info**:
   - **iPhone**: ✓
   - **iPad**: ✓ (if supporting iPad)
   - **Minimum Deployment**: iOS 17.0
   - **Supported orientations**: Portrait (minimum)

---

## Part 5: Test Build

### Step 1: Select Scheme

1. In Xcode toolbar, click scheme dropdown (next to device selector)
2. Select **OralableForDentists**

### Step 2: Select Destination

1. Click device dropdown
2. Select an iOS Simulator (e.g., iPhone 15 Pro)

### Step 3: Build

1. Press **⌘B** to build
2. Watch for errors in the Issue Navigator (left panel, triangle icon)

### Common Build Issues:

**Issue**: "Cannot find 'Logger' in scope"
- **Fix**: Make sure Logger.swift and LoggingService.swift have both targets checked

**Issue**: "Cannot find 'DesignSystem' in scope"
- **Fix**: Add all DesignSystem files to OralableForDentists target membership

**Issue**: "Duplicate symbol"
- **Fix**: Don't copy the placeholder Logger class - it should be deleted

**Issue**: Entitlements/Info.plist not found
- **Fix**: Check Build Settings paths are correct

### Step 4: Run

If build succeeds:
1. Press **⌘R** to run
2. App should launch in simulator
3. You should see the dentist onboarding screen

---

## Part 6: Verify Configuration

### Checklist:

- [ ] Dentist app builds successfully
- [ ] Dentist app runs in simulator
- [ ] Onboarding screen displays correctly
- [ ] No compiler warnings about missing types
- [ ] Both targets can build independently
- [ ] Switching between schemes works (OralableApp ↔ OralableForDentists)

### Files That Should Be Shared (both targets):

- `DesignSystem.swift` and related design files
- `Logger.swift`
- `LoggingService.swift`
- Any utility extensions (String+, Date+, etc.)

### Files That Should NOT Be Shared:

- App entry points (Oralable.swift vs OralableForDentists.swift)
- Target-specific managers (AppStateManager vs DentistDataManager)
- Target-specific views
- Target-specific ViewModels

---

## Troubleshooting

### Build Errors

1. **Clean Build Folder**: ⌘⇧K
2. **Derived Data**: Product → Clean Build Folder
3. **Restart Xcode**
4. Check that files are added to correct targets

### Target Membership Issues

To check/fix target membership:
1. Select any file
2. Open **File Inspector** (⌥⌘1)
3. Look at **Target Membership** section
4. Check appropriate boxes

### Scheme Issues

If OralableForDentists scheme is missing:
1. Product → Scheme → Manage Schemes
2. Click **+** to add new scheme
3. Select **OralableForDentists** target
4. Click OK

---

## Next Steps

Once Xcode configuration is complete:
1. ✅ Test both apps in simulator
2. ✅ Configure CloudKit schema (Apple Developer Portal)
3. ✅ Set up App Store Connect products
4. ✅ Test data sharing between apps
5. ✅ Prepare for TestFlight

Proceed to: **TESTING_AND_DEPLOYMENT_GUIDE.md** (to be created next)
