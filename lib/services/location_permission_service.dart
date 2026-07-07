import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  unavailable,
}

class LocationAccessResult {
  const LocationAccessResult({
    required this.status,
    this.position,
    this.message = '',
  });

  final LocationAccessStatus status;
  final Position? position;
  final String message;

  bool get isGranted => status == LocationAccessStatus.granted;
}

class LocationPermissionService {
  const LocationPermissionService();

  Future<LocationAccessResult> requestCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationAccessResult(
          status: LocationAccessStatus.serviceDisabled,
          message: 'Location services are switched off.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationAccessResult(
          status: LocationAccessStatus.denied,
          message: 'Location permission is required to find services nearby.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationAccessResult(
          status: LocationAccessStatus.deniedForever,
          message: 'Location permission is blocked in system settings.',
        );
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return const LocationAccessResult(
          status: LocationAccessStatus.unavailable,
          message: 'Unable to detect your current location.',
        );
      }

      return LocationAccessResult(
        status: LocationAccessStatus.granted,
        position: position,
      );
    } catch (error) {
      return LocationAccessResult(
        status: LocationAccessStatus.unavailable,
        message: 'Unable to access location: $error',
      );
    }
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
