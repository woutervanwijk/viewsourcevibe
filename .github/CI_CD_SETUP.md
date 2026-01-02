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
2. **Apple Developer Account** - For iOS app signing and distribution
3. **Google Play Developer Account** - For Android app distribution
4. **Fastlane Installed** - `gem install fastlane`
5. **Flutter Installed** - Version 3.19.0 or compatible

## 🛠️ Setup Instructions

### 1. Add Secrets to GitHub Repository

Go to your GitHub repository **Settings > Secrets > Actions** and add the following secrets:

#### iOS Secrets:
- `APPLE_CERTIFICATE_P12` - Base64 encoded .p12 certificate file
- `APPLE_CERTIFICATE_PASSWORD` - Password for the certificate
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

### 1. iOS CI/CD (`ios-ci-cd.yml`)

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

### 2. Android CI/CD (`android-ci-cd.yml`)

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

### 3. Combined CI/CD (`combined-ci-cd.yml`)

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

### iOS Certificate Setup

1. **Export Certificate**:
```bash
# On your Mac, export the certificate
security export -k ~/Library/Keychains/login.keychain -t certs -o cert.p12 -P your_password
```

2. **Base64 Encode**:
```bash
base64 -i cert.p12 -o cert_base64.txt
```

3. **Add to GitHub Secrets**:
```bash
# Copy the content of cert_base64.txt to APPLE_CERTIFICATE_P12 secret
```

### Provisioning Profile Setup

1. **Export Profile**:
```bash
# Find your provisioning profile UUID
ls ~/Library/MobileDevice/Provisioningiles/Profiles/

# Export the profile
cp ~/Library/MobileDevice/Provisioningiles/Profiles/UUID.mobileprovision profile.mobileprovision
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

- **Push to `develop`**: Builds and deploys to TestFlight (iOS) and Beta (Android)
- **Push to `main`**: Builds and deploys to App Store (iOS) and Production (Android)
- **Pull Requests**: Runs tests and builds but doesn't deploy

### Manual Triggers

You can manually trigger workflows from the GitHub Actions tab:

1. Go to **Actions** tab in your repository
2. Select the workflow you want to run
3. Click **Run workflow**
4. Select branch and run

### Local Testing

Test Fastlane lanes locally before pushing:

```bash
# Test iOS build
fastlane ios build_ios

# Test Android build
fastlane android build_android

# Run tests
fastlane test
```

## ⚠️ Troubleshooting

### Common Issues

#### 1. Certificate/Provisioning Profile Issues

**Error**: "No certificate found" or "No provisioning profile found"

**Solution**:
- Verify secrets are correctly set in GitHub
- Check certificate and profile are not expired
- Ensure bundle identifier matches in Xcode and Fastlane

#### 2. Fastlane Version Mismatch

**Error**: "Fastlane version mismatch"

**Solution**:
```bash
# Update Fastlane
gem update fastlane

# Check version
fastlane --version
```

#### 3. Flutter Version Issues

**Error**: "Flutter version mismatch"

**Solution**:
- Update `FLUTTER_VERSION` in workflow files
- Run `flutter upgrade` locally
- Ensure all developers use same Flutter version

#### 4. Build Failures

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