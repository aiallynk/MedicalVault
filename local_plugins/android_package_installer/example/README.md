# android_package_installer_example
A Flutter plugin for installing apk file from disk. Use Android Package Installer.
Plugin requires minimum API Level version 21

## Using

## Setup
Add the permissions to your AndroidManifest.xml file in `<projectDir>/android/app/src/main/AndroidManifest.xml`:

* `android.permission.REQUEST_INSTALL_PACKAGES` - required for installing android packages.
* `android.permission.READ_EXTERNAL_STORAGE` - required to access the external storage from where you want to install the apk file.

```xml
<manifest xmlns:tools="http://schemas.android.com/tools" ...>
  <!-- ADD THESE PERMISSIONS -->
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
  
  <application ...>
    ... 
  </application>
</manifest>
```

Check or add file paths in file `<projectDir>/android/app/src/main/res/xml/file_paths.xml`.
If it doesn't exist, create it:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ADD THIS -->
    <external-path name="external_files" path="."/>
    
</paths>
```
Then add 

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
