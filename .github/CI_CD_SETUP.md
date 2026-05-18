# 🚀 CI/CD Setup with Fastlane and GitHub Actions

This guide explains how to set up and use the CI/CD pipelines for ViewSourceVibe.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Available Workflows](#available-workflows)
- [Secrets Configuration](#secrets-configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)

## 🔧 Prerequisites

Before setting up CI/CD, ensure you have:

1. **GitHub Repository** - Your project should be on GitHub
2. **Apple Developer Account** - For iOS app signing and macOS Developer ID notarization
3. **Google Play Developer Account** - For Android app distribution
4. **Fastlane Installed** - `gem install fastlane`
5. **Flutter Installed** - The desktop workflow currently pins Flutter `3.41.6`

## 🛠️ Setup Instructions

### 1. Add Secrets to GitHub Repository

Go to your GitHub repository **Settings > Secrets > Actions** and add the following secrets:

#### macOS Desktop Release Secrets:
- `APPLE_CERTIFICATE_P12` - Base64 encoded .p12 certificate file
- `APPLE_CERTIFICATE_PASSWORD` - Password for the certificate
- `APPLE_ID` - Apple ID used for notarization
- `APPLE_PASSWORD` - App-specific password for the Apple ID
- `APPLE_TEAM_ID` - Apple Developer Team ID

The macOS desktop workflow expects the `.p12` to contain a **Developer ID Application** certificate. This is required for a signed, notarized DMG distributed outside the Mac App Store.

#### iOS Secrets:
- `APPLE_PROVISIONING_PROFILE` - Base64 encoded provisioning profile
- `APP_STORE_CONNECT_API_KEY_PATH` - Path to App Store Connect API key
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID` - Issuer ID for API key
- `APP_STORE_CONNECT_API_KEY_KEY_ID` - Key ID for API key

#### Android Secrets:
- `GOOGLE_PLAY_JSON_KEY_PATH` - Path to Google Play service account JSON key

#### Common Secrets:
- `SLACK_WEBHOOK` - Slack webhook URL for notifications (optional)

### 2. Configure App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access > Keys**
3. Click **+** to create a new API key
4. Download the `.p8` file
5. Add the key to your Fastlane directory

### 3. Configure Google Play API Access

1. Go to [Google Play Console](https://play.google.com/console/)
2. Navigate to **API Access** in Settings
3. Create a service account
4. Download the JSON key file
5. Add the key to your Fastlane directory

### 4. Update App Identifiers

Update the following files with your actual app identifiers:

- `fastlane/Appfile` - Update `app_identifier` and `package_name`
- `ios/Runner/Info.plist` - Update bundle identifier
- `android/app/build.gradle` - Update applicationId

## 🔄 Available Workflows

### 1. Desktop Releases (`build-desktop.yml`)

**Triggers:**
- Push tags matching `v*`, for example `v1.1.4`
- Manual runs from the GitHub Actions UI

**Jobs:**
- **build-macos**: Builds the Flutter macOS app, imports the Developer ID certificate into a temporary keychain, signs the app with hardened runtime, creates a DMG, signs/notarizes/staples the DMG, and uploads it as an artifact.
- **build-windows**: Builds the Flutter Windows app and packages it with Inno Setup.
- **create-release**: On tag builds, creates a GitHub Release containing the macOS DMG and Windows installer.

**Usage:**
```bash
git tag v1.1.4
git push origin v1.1.4
```

If a tag needs to be rebuilt, delete and recreate the remote tag carefully:

```bash
git push origin :refs/tags/v1.1.4
git tag -f v1.1.4
git push origin v1.1.4 --force
```

### 2. iOS CI/CD (`ios-ci-cd.yml.disabled`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Changes to iOS, lib, or pubspec.yaml files

**Jobs:**
- **Build and Test**: Runs on macOS, builds iOS app, runs tests
- **Deploy to TestFlight**: Uploads to TestFlight on `develop` branch
- **Deploy to App Store**: Uploads to App Store on `main` branch
- **Slack Notification**: Sends build status to Slack

**Usage:**
```bash
# Manual trigger (not recommended, use GitHub UI)
gh workflow run ios-ci-cd.yml
```

### 3. Android CI/CD (`android-ci-cd.yml.disabled`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Changes to Android, lib, or pubspec.yaml files

**Jobs:**
- **Build and Test**: Runs on Ubuntu, builds Android app bundle, runs tests
- **Deploy to Beta**: Uploads to Google Play Beta track on `develop` branch
- **Deploy to Production**: Uploads to Google Play Production on `main` branch
- **Slack Notification**: Sends build status to Slack

**Usage:**
```bash
# Manual trigger (not recommended, use GitHub UI)
gh workflow run android-ci-cd.yml
```

### 4. Combined CI/CD (`combined-ci-cd.yml.disabled`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Ignores documentation changes

**Jobs:**
- **iOS Build**: Runs iOS build in parallel
- **Android Build**: Runs Android build in parallel
- **Combined Notification**: Sends combined status to Slack

**Usage:**
```bash
# Manual trigger (not recommended, use GitHub UI)
gh workflow run combined-ci-cd.yml
```

## 🔐 Secrets Configuration

### macOS Developer ID Certificate Setup

1. **Export Certificate**:
```bash
# On your Mac, export the Developer ID Application certificate
security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 -o cert.p12 -P your_password
```

2. **Base64 Encode**:
```bash
base64 -i cert.p12 -o cert_base64.txt
```

3. **Add to GitHub Secrets**:
```bash
# Copy the content of cert_base64.txt to APPLE_CERTIFICATE_P12 secret
```

The password passed to `security export` must be stored as `APPLE_CERTIFICATE_PASSWORD`.

### macOS Notarization Password Setup

Create an app-specific password for the Apple ID used for notarization:

1. Go to [account.apple.com](https://account.apple.com/).
2. Open **Sign-In and Security > App-Specific Passwords**.
3. Generate a password for GitHub Actions.
4. Store it as `APPLE_PASSWORD`.
5. Store the Apple ID as `APPLE_ID` and the Apple Developer Team ID as `APPLE_TEAM_ID`.

### iOS Certificate Setup

The disabled iOS workflow uses separate provisioning profile setup and App Store Connect configuration. Keep those secrets only if re-enabling iOS CI/CD.

### Provisioning Profile Setup

1. **Export Profile**:
```bash
# Find your provisioning profile UUID
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Export the profile
cp ~/Library/MobileDevice/Provisioning\ Profiles/UUID.mobileprovision profile.mobileprovision
```

2. **Base64 Encode**:
```bash
base64 -i profile.mobileprovision -o profile_base64.txt
```

3. **Add to GitHub Secrets**:
```bash
# Copy the content of profile_base64.txt to APPLE_PROVISIONING_PROFILE secret
```

## 🚀 Usage

### Automatic Triggers

The workflows are set up to trigger automatically:

- **Push a `v*` tag**: Builds signed/notarized macOS DMG and Windows installer, then creates a GitHub Release
- **Manual workflow run**: Builds desktop artifacts without needing a new tag

The iOS, Android, and combined CI/CD workflows are currently disabled with `.disabled` filenames.

### Manual Triggers

You can manually trigger workflows from the GitHub Actions tab:

1. Go to **Actions** tab in your repository
2. Select the workflow you want to run
3. Click **Run workflow**
4. Select branch and run

### Local Testing

Test Flutter and Fastlane lanes locally before pushing:

```bash
# Test Flutter
flutter analyze
flutter test

# Test desktop builds
flutter build macos --release
flutter build windows --release

# Test iOS build
fastlane ios build_ios

# Test Android build
fastlane android build_android

# Run tests
fastlane test
```

## ⚠️ Troubleshooting

### Common Issues

#### 1. macOS Developer ID Signing Issues

**Error**: "No Developer ID Application signing identity found in the keychain."

**Solution**:
- Verify `APPLE_CERTIFICATE_P12` contains a Developer ID Application certificate and private key
- Check `APPLE_CERTIFICATE_PASSWORD` matches the exported `.p12`
- Confirm the certificate is not expired or revoked
- Export the certificate as a PKCS#12 identity, not only as a public certificate

#### 2. macOS Notarization Issues

**Error**: `notarytool` authentication or submission failure

**Solution**:
- Verify `APPLE_ID`, `APPLE_PASSWORD`, and `APPLE_TEAM_ID`
- Ensure `APPLE_PASSWORD` is an app-specific password, not the normal Apple ID password
- Check Apple Developer Program membership and agreements
- Read the notarytool log URL in the GitHub Actions output

#### 3. Certificate/Provisioning Profile Issues

**Error**: "No certificate found" or "No provisioning profile found"

**Solution**:
- Verify secrets are correctly set in GitHub
- Check certificate and profile are not expired
- Ensure bundle identifier matches in Xcode and Fastlane

#### 4. Fastlane Version Mismatch

**Error**: "Fastlane version mismatch"

**Solution**:
```bash
# Update Fastlane
gem update fastlane

# Check version
fastlane --version
```

#### 5. Flutter Version Issues

**Error**: "Flutter version mismatch"

**Solution**:
- Update `FLUTTER_VERSION` in workflow files
- Run `flutter upgrade` locally
- Ensure all developers use same Flutter version

#### 6. Build Failures

**Error**: "Build failed with errors"

**Solution**:
- Check GitHub Actions logs for specific errors
- Run `flutter analyze` and `flutter test` locally
- Verify all dependencies are up to date

### Debugging

Add debug output to Fastlane:

```ruby
# In your Fastfile
UI.message("Debug: Current version = #{get_version_number}")
UI.important("Starting iOS build...")
```

View logs with:
```bash
# Increase verbosity
FASTLANE_VERBOSE=1 fastlane ios build_ios
```

## 📚 Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Google Play Developer API](https://developers.google.com/android-publisher)

## 🎉 Success!

Your CI/CD pipeline is now set up and ready to use. The workflows will:

✅ **Automatically build** on every push
✅ **Run all tests** to ensure quality
✅ **Deploy to TestFlight/Beta** on develop branch
✅ **Deploy to App Store/Production** on main branch
✅ **Notify on Slack** about build status
✅ **Handle errors gracefully** with proper notifications

Enjoy automated deployments! 🚀
