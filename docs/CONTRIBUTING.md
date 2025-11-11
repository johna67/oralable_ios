# Contributing to Oralable iOS

Thank you for your interest in contributing to Oralable iOS! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. Please:

- ✅ Be respectful and inclusive
- ✅ Welcome newcomers
- ✅ Focus on what is best for the community
- ✅ Show empathy towards other community members

### Unacceptable Behavior

- ❌ Harassment or discrimination
- ❌ Trolling or insulting comments
- ❌ Publishing others' private information
- ❌ Other unprofessional conduct

## Getting Started

### 1. Fork the Repository

```bash
# Click "Fork" on GitHub, then:
git clone https://github.com/YOUR_USERNAME/oralable_ios.git
cd oralable_ios
```

### 2. Set Up Development Environment

Follow the [SETUP.md](SETUP.md) guide to configure your development environment.

### 3. Create a Branch

```bash
# Create a branch for your feature/fix
git checkout -b feature/your-feature-name

# Or for a bug fix
git checkout -b fix/bug-description
```

**Branch Naming Conventions**:
- `feature/`: New features
- `fix/`: Bug fixes
- `docs/`: Documentation changes
- `refactor/`: Code refactoring
- `test/`: Adding or updating tests
- `chore/`: Maintenance tasks

## Development Workflow

### 1. Make Your Changes

- Write clean, documented code
- Follow existing code style
- Add tests for new features
- Update documentation as needed

### 2. Test Your Changes

```bash
# Run tests
⌘+U in Xcode
# Or via command line:
xcodebuild test -project OralableApp/OralableApp.xcodeproj -scheme OralableApp
```

### 3. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "feat: add SpO2 trend analysis feature"
```

**Commit Message Format**:
```
<type>: <subject>

<body> (optional)

<footer> (optional)
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

**Examples**:
```bash
git commit -m "feat: add historical data export to PDF"
git commit -m "fix: resolve BLE connection timeout issue"
git commit -m "docs: update README with StoreKit setup"
git commit -m "test: add SettingsViewModel unit tests"
```

### 4. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select your branch
4. Fill in the PR template
5. Submit!

## Coding Standards

### Swift Style Guide

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

### Key Principles

#### 1. Naming

```swift
// ✅ Good
func calculateHeartRate(from ppgData: PPGData) -> Int

// ❌ Bad
func calc(d: PPGData) -> Int
```

#### 2. Comments

```swift
// ✅ Good - Explain WHY
// Debounce scanning to prevent rapid UI updates
func debounceScanning()

// ❌ Bad - Explain WHAT (obvious from code)
// This function scans for devices
func scanForDevices()
```

#### 3. SwiftUI Views

```swift
// ✅ Good - Break into computed properties
struct DashboardView: View {
    var body: some View {
        contentView
    }

    private var contentView: some View {
        VStack {
            headerSection
            metricsSection
        }
    }

    private var headerSection: some View {
        // Header implementation
    }
}

// ❌ Bad - Everything in body
struct DashboardView: View {
    var body: some View {
        VStack {
            // 200 lines of view code...
        }
    }
}
```

#### 4. MVVM Pattern

```swift
// ✅ Good - ViewModel handles logic
class DashboardViewModel: ObservableObject {
    @Published var heartRate: Int = 0

    func calculateHeartRate(from data: PPGData) {
        // Complex calculation logic
    }
}

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        Text("\(viewModel.heartRate) BPM")
    }
}

// ❌ Bad - View handles logic
struct DashboardView: View {
    @State private var heartRate = 0

    var body: some View {
        Text("\(heartRate) BPM")
            .onAppear {
                // Complex calculation in view
            }
    }
}
```

### Code Organization

#### File Structure

```swift
// ✅ Good organization
import SwiftUI

// MARK: - Main View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        // Implementation
    }
}

// MARK: - Subviews
private struct SettingRow: View {
    // Implementation
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
```

### Documentation

```swift
/// Calculates SpO2 percentage from PPG data
/// - Parameters:
///   - red: Red wavelength PPG values
///   - ir: Infrared wavelength PPG values
/// - Returns: SpO2 percentage (0-100), or nil if calculation fails
func calculateSpO2(red: [Double], ir: [Double]) -> Int? {
    // Implementation
}
```

## Testing Guidelines

### Unit Test Structure

```swift
class ExampleViewModelTests: XCTestCase {
    var viewModel: ExampleViewModel!
    var mockBLE: OralableBLE!

    override func setUp() {
        super.setUp()
        mockBLE = OralableBLE.mock()
        viewModel = ExampleViewModel(bleManager: mockBLE)
    }

    override func tearDown() {
        viewModel = nil
        mockBLE = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testFeatureX() {
        // Given
        viewModel.property = value

        // When
        viewModel.doSomething()

        // Then
        XCTAssertEqual(viewModel.result, expectedValue)
    }
}
```

### Test Naming

```swift
// ✅ Good
func testHeartRateCalculationWithValidPPGData()
func testConnectionFailureHandling()
func testSubscriptionRestoreWithNoPreviousPurchases()

// ❌ Bad
func test1()
func testStuff()
func testHeartRate()
```

### Test Coverage

- New features should have 80%+ test coverage
- Bug fixes should include regression tests
- Critical paths (BLE, subscriptions) need comprehensive tests

## Pull Request Process

### Before Submitting

- [ ] Code builds without warnings
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] Code follows style guide
- [ ] No merge conflicts

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Checklist
- [ ] Tests pass
- [ ] Code follows style guide
- [ ] Documentation updated
- [ ] No warnings
```

### Review Process

1. **Automated Checks**: GitHub Actions runs tests
2. **Code Review**: Maintainer reviews code
3. **Discussion**: Address feedback
4. **Approval**: Maintainer approves
5. **Merge**: Code merged to main

### Addressing Feedback

```bash
# Make requested changes
git add .
git commit -m "refactor: address PR feedback"
git push origin feature/your-feature-name
```

## Issue Guidelines

### Creating Issues

Use the appropriate template:

#### Bug Report
```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '....'
3. See error

**Expected behavior**
What should happen

**Screenshots**
If applicable

**Environment**
- iOS version:
- Device:
- App version:
```

#### Feature Request
```markdown
**Is your feature request related to a problem?**
Clear description

**Describe the solution you'd like**
What you want to happen

**Describe alternatives you've considered**
Other solutions

**Additional context**
Any other context
```

### Working on Issues

```bash
# Reference issue in commits
git commit -m "fix: resolve BLE timeout (#123)"

# Reference in PR description
Fixes #123
Closes #456
Related to #789
```

## Code Review Checklist

### For Reviewers

- [ ] Code follows Swift style guide
- [ ] Tests are comprehensive and passing
- [ ] Documentation is clear and updated
- [ ] No unnecessary complexity
- [ ] Performance implications considered
- [ ] Security implications considered
- [ ] Accessibility considered

### For Contributors

- [ ] Self-review completed
- [ ] Screenshots/videos for UI changes
- [ ] Breaking changes documented
- [ ] Migration guide provided (if needed)

## Development Tips

### Debugging

```swift
// Use print statements with emojis for visibility
print("🔵 BLE: Device discovered - \(device.name)")
print("🔴 ERROR: Connection failed - \(error)")
print("✅ SUCCESS: Data saved")
```

### Testing BLE

- Use physical device
- Check Bluetooth permissions
- Monitor logs for BLE events
- Use BLE scanner app to verify device advertising

### Testing StoreKit

- Use StoreKit configuration file
- Test all purchase states
- Test restore purchases
- Test subscription renewal

## Getting Help

- **Questions**: [GitHub Discussions](https://github.com/johna67/oralable_ios/discussions)
- **Bugs**: [GitHub Issues](https://github.com/johna67/oralable_ios/issues)
- **Chat**: (Add Discord/Slack link if available)

## Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes
- Special thanks in README

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Oralable iOS! 🎉
