# Nearby Healthcare Services Integration

## Files Analyzed

- `lib/main.dart`
- `lib/BottomNavigationBar/dashboard1.dart`
- `lib/screens/nearby_services_page.dart`
- `lib/api_service.dart`
- `lib/services/offline/offline_storage_service.dart`
- `lib/screens/sos_page.dart`
- `lib/features/lost_found/report_lost_page.dart`
- `lib/features/lost_found/report_found_page.dart`
- `lib/core/theme/*`
- `lib/widgets/custom_card.dart`
- `lib/widgets/app_text.dart`
- `pubspec.yaml`
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `ios/Runner/AppDelegate.swift`
- `Backend-MedicalVault/routes/nearby.js`

## Existing Architecture

- State management: `provider` with local/global `ChangeNotifier` providers.
- Navigation: direct `Navigator.push` / custom fade routes from dashboard and FAB actions.
- Nearby entry point: dashboard radial FAB already opens `NearbyServicesPage`.
- Existing location flow: `geolocator` is used in SOS and lost/found flows.
- Existing API style: `ApiService` centralizes backend calls; old nearby page used `ApiService.fetchNearbyServices`.
- Offline storage: encrypted Hive through `OfflineStorageService`.
- UI style: Material 3 theme, `CustomCard`, `AppText`, app color/radius/spacing primitives.
- Existing backend nearby route: uses legacy Google Places Nearby Search endpoint, not Places API New.

## Implementation Summary

- Replaced the old backend-backed nearby list with a full Flutter module using Places API New.
- Added Provider-backed state for category loading, filtering, local search, favorites, cache flags, and lazy result display.
- Added Google Maps list/map toggle with current-location marker, place markers, basic zoom-aware clustering, and camera bounds fitting.
- Added emergency quick access for India: ambulance `108`, emergency `112`, and nearby ambulance search.
- Added reusable services and model:
  - `NearbyPlace`
  - `NearbyPlacesService`
  - `LocationPermissionService`
  - `NearbyHealthcareProvider`
  - `AppEnvironment`
- Extended encrypted Hive storage for:
  - 15-minute nearby results cache
  - recent searches
  - saved favorite places

## Google Places API New Mapping

- Hospitals: Nearby Search New with `includedTypes: ["hospital"]`.
- Medical stores/pharmacies: Nearby Search New with `includedTypes: ["pharmacy"]`.
- Clinics: Text Search New with `textQuery: "clinic"`.
- Ambulances: Text Search New using `ambulance`, `emergency service`, and `ambulance provider`.
- Ambulance fallback: Text Search New for `emergency hospital` with `includedType: "hospital"`.
- Distance sorting: `Geolocator.distanceBetween()` converted to kilometers.
- Requested fields use explicit field masks for name, address, coordinates, rating, opening status, phone, maps URL, and types.

## New Files

- `.env.example`
- `NEARBY_HEALTHCARE_SERVICES_INTEGRATION.md`
- `ios/Flutter/GoogleMapsKeys.xcconfig.example`
- `ios/Podfile`
- `lib/config/app_environment.dart`
- `lib/models/nearby_place.dart`
- `lib/providers/nearby_healthcare_provider.dart`
- `lib/services/location_permission_service.dart`
- `lib/services/nearby_places_service.dart`

## Modified Files

- `.gitignore`
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Info.plist`
- `lib/main.dart`
- `lib/screens/nearby_services_page.dart`
- `lib/services/offline/offline_storage_service.dart`
- `pubspec.yaml`
- `pubspec.lock`

## Dependencies Added

- `google_maps_flutter`
- `flutter_dotenv`

Existing reused dependencies:

- `provider`
- `geolocator`
- `http`
- `url_launcher`
- `connectivity_plus`
- `hive`
- `hive_flutter`

## Configuration

Required variable:

```env
GOOGLE_MAPS_API_KEY=YOUR_API_KEY
```

Dart reads the key from `--dart-define=GOOGLE_MAPS_API_KEY=...` first, then `.env`.

Android reads the key from:

1. `GOOGLE_MAPS_API_KEY` environment variable
2. `android/local.properties`
3. project `.env`
4. legacy `MAPS_API_KEY` fallback

iOS reads `GoogleMapsApiKey` from `$(GOOGLE_MAPS_API_KEY)` via optional `ios/Flutter/GoogleMapsKeys.xcconfig`.

## Setup

1. Enable these Google Cloud APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API New
2. Create local config:

```powershell
Copy-Item .env.example .env
```

3. Add the key to `.env`:

```env
GOOGLE_MAPS_API_KEY=YOUR_API_KEY
```

4. For iOS local builds:

```powershell
Copy-Item ios\Flutter\GoogleMapsKeys.xcconfig.example ios\Flutter\GoogleMapsKeys.xcconfig
```

Then set `GOOGLE_MAPS_API_KEY` inside that file.

5. Run:

```powershell
flutter pub get
flutter run
```

## Verification

- `dart analyze` on new module files: passed.
- `flutter test`: passed.
- `flutter analyze`: still exits nonzero because of 315 pre-existing infos in older files.
- `flutter build apk --debug`: attempted, but timed out after 10 minutes before completion.
- iOS build was not run in this Windows environment.

## Testing Checklist

- First launch prompts for location permission.
- Denied permission shows explanation dialog.
- Permanently denied permission opens app settings.
- Disabled GPS opens location settings.
- Hospitals, clinics, medical stores, and ambulances load independently.
- Recent searches persist.
- Distance, rating, and open-now filters apply.
- Result list sorts nearest first.
- Call action opens dialer.
- Google Maps action opens the place.
- Favorite action persists locally.
- List/map toggle works.
- Map shows user marker and place markers.
- Camera bounds fit visible results.
- Cached data appears during no-internet/API-failure cases.

## Production Readiness

- Restrict Android key by package name `com.example.hello` and signing SHA-1.
- Restrict iOS key by the final Bundle ID.
- Apply API restrictions to only Maps SDK for Android, Maps SDK for iOS, and Places API New.
- Use separate keys per platform for production.
- Rotate any key that was ever committed or shared.
- Monitor Places usage and set billing alerts.
- For stronger key protection, move Places REST calls behind a backend proxy with auth, rate limiting, and abuse monitoring.
