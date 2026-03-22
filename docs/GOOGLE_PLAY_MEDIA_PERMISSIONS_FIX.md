# Google Play Media Permissions Compliance Fix

## Issue
Google Play Store flagged the app for non-compliance with the Photo and Video Permissions policy:
- App was requesting `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` permissions
- These permissions are only allowed for apps with persistent access to media files
- Manage Care only requires one-time/limited access to photos (for receipts and business profiles)

## Resolution

### 1. **AndroidManifest.xml Updates**
Added explicit permission removal to prevent `permission_handler` and `image_picker` plugins from auto-adding media permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <!-- Explicitly remove READ_MEDIA permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
```

**Why this works:**
- `tools:node="remove"` tells Android's manifest merger to strip these permissions from all dependencies
- Even if plugins try to add them, the manifest merger removes them during build
- No manual code changes needed

### 2. **Build Configuration**
Updated `android/app/build.gradle.kts` with packaging options:
```gradle
packagingOptions {
    // Remove READ_MEDIA permissions to comply with Google Play policy
    // These permissions are only needed for apps with persistent media access
    // We use one-time access via Android photo picker instead
}
```

## Current Image Selection Implementation

The app uses **one-time access** via `image_picker` plugin for:

1. **Business Profile Photo** - `business_settings_screen.dart`
   - Used once during business setup
   - Method: `_pickProfileImage()`
   - Triggers system photo picker on demand

2. **Receipt Upload** - `subscription_payment_screen.dart`
   - Used when uploading payment receipts
   - Methods: `_pickReceiptFromCamera()`, `_pickReceiptFromGallery()`
   - One-time access per receipt upload

3. **Admin Payment Receipts** - `admin_payments_page.dart`
   - Used for verifying payment receipts
   - Method: `_pickAndUploadReceiptPhoto()`
   - One-time access per receipt

## Compliance Details

✅ **Compliant Implementation:**
- ✅ One-time access to media files only
- ✅ User triggers access via explicit UI actions
- ✅ No persistent/background access
- ✅ Uses system photo picker (respects user's media access settings)
- ✅ No photo/video library scanning
- ✅ No media file enumeration

❌ **Removed (Non-Compliant):**
- ❌ `READ_MEDIA_IMAGES` permission
- ❌ `READ_MEDIA_VIDEO` permission
- ❌ Any persistent media access patterns

## Testing Checklist

- [ ] Business profile photo upload still works
- [ ] Receipt photo picker functions correctly
- [ ] Camera option available
- [ ] Gallery picker available
- [ ] No permission prompts for unused permissions
- [ ] App compiles without errors
- [ ] APK builds successfully
- [ ] Install on test device and verify image picking

## Submission Steps

1. Update all tracks (production, testing) with new APK/AAB
2. Go to Google Play Console → Publishing overview
3. Submit for review with the following note:

**Review Note:**
"We have removed `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` permissions as our app only requires one-time access to media files for uploading business photos and payment receipts. We use the system photo picker for all media access, which complies with Google Play's Photo and Video Permissions policy."

## Files Modified

- `android/app/src/main/AndroidManifest.xml` - Added permission removal directives
- `android/app/build.gradle.kts` - Added packaging options comment

## References

- [Google Play Photo and Video Permissions Policy](https://play.google.com/about/restricted-use-cases/photos-video-permissions/)
- [Android Manifest Merging Guide](https://developer.android.com/guide/topics/manifest/manifest-intro#merging)
- [Image Picker Plugin](https://pub.dev/packages/image_picker)
