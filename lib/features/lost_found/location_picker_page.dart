import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/app_environment.dart';
import '../../localization/app_localizations.dart';

class LostFoundPickedLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const LostFoundPickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LostFoundLocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String? title;

  const LostFoundLocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.title,
  });

  @override
  State<LostFoundLocationPickerPage> createState() =>
      _LostFoundLocationPickerPageState();
}

class _LostFoundLocationPickerPageState
    extends State<LostFoundLocationPickerPage> {
  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);

  GoogleMapController? _mapController;
  LatLng? _selected;
  String? _address;
  bool _loadingCurrentLocation = false;
  bool _resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    final initialLat = widget.initialLatitude;
    final initialLng = widget.initialLongitude;
    if (initialLat != null && initialLng != null) {
      _selected = LatLng(initialLat, initialLng);
      _address = widget.initialAddress;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final l10n = context.l10n;
    try {
      setState(() => _loadingCurrentLocation = true);
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage(l10n.t('sos.locationServicesDisabled'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage(l10n.t('sos.locationPermissionDenied'));
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(l10n.t('sos.locationPermissionForever'));
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await _selectLocation(
        LatLng(position.latitude, position.longitude),
        animate: true,
      );
    } catch (error) {
      _showMessage(l10n.format('sos.locationError', {'error': '$error'}));
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  Future<void> _selectLocation(
    LatLng target, {
    bool animate = false,
  }) async {
    setState(() {
      _selected = target;
      _resolvingAddress = true;
    });

    if (animate) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16),
        ),
      );
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );
      if (!mounted) return;
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final address = [
        place?.street,
        place?.locality,
        place?.administrativeArea,
        place?.country,
      ].where((entry) => entry != null && entry.trim().isNotEmpty).join(', ');
      setState(() {
        _address = address.trim().isNotEmpty ? address.trim() : null;
        _resolvingAddress = false;
      });
    } catch (_) {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _showCoordinateDialog() async {
    final l10n = context.l10n;
    final latController = TextEditingController(
      text: _selected?.latitude.toStringAsFixed(6) ?? '',
    );
    final lngController = TextEditingController(
      text: _selected?.longitude.toStringAsFixed(6) ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('lostReport.enterCoordinates')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: InputDecoration(
                labelText: l10n.t('lostReport.latitude'),
                hintText: '20.000000',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              decoration: InputDecoration(
                labelText: l10n.t('lostReport.longitude'),
                hintText: '73.000000',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              if (lat == null ||
                  lng == null ||
                  lat < -90 ||
                  lat > 90 ||
                  lng < -180 ||
                  lng > 180) {
                _showMessage(l10n.t('lostReport.invalidCoordinates'));
                return;
              }
              Navigator.pop(dialogContext);
              _selectLocation(LatLng(lat, lng), animate: true);
            },
            child: Text(l10n.t('common.confirm')),
          ),
        ],
      ),
    );
  }

  void _confirmSelection() {
    final selected = _selected;
    if (selected == null) {
      _showMessage(context.l10n.t('common.locationNotSet'));
      return;
    }
    Navigator.pop(
      context,
      LostFoundPickedLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        address: _address,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', '').trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = _selected;
    final initialTarget = selected ?? _indiaCenter;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.t('lostReport.selectLocation')),
        actions: [
          TextButton(
            onPressed: selected == null ? null : _confirmSelection,
            child: Text(l10n.t('common.confirm')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AppEnvironment.hasGoogleMapsApiKey
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialTarget,
                        zoom: selected == null ? 5 : 16,
                      ),
                      myLocationButtonEnabled: false,
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (selected != null) {
                          controller.moveCamera(
                            CameraUpdate.newLatLngZoom(selected, 16),
                          );
                        }
                      },
                      onTap: _selectLocation,
                      markers: {
                        if (selected != null)
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: selected,
                            draggable: true,
                            onDragEnd: _selectLocation,
                          ),
                      },
                    )
                  : _CoordinateOnlyPicker(
                      selected: selected,
                      onEnterCoordinates: _showCoordinateDialog,
                    ),
            ),
            _SelectionPanel(
              selected: selected,
              address: _address,
              resolvingAddress: _resolvingAddress,
              loadingCurrentLocation: _loadingCurrentLocation,
              onUseCurrentLocation: _useCurrentLocation,
              onEnterCoordinates: _showCoordinateDialog,
              onConfirm: _confirmSelection,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinateOnlyPicker extends StatelessWidget {
  final LatLng? selected;
  final VoidCallback onEnterCoordinates;

  const _CoordinateOnlyPicker({
    required this.selected,
    required this.onEnterCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEnterCoordinates,
      child: Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  selected == null
                      ? context.l10n.t('lostReport.tapToSelect')
                      : '${selected!.latitude.toStringAsFixed(6)}, '
                          '${selected!.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.t('lostReport.enterCoordinates'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  final LatLng? selected;
  final String? address;
  final bool resolvingAddress;
  final bool loadingCurrentLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onEnterCoordinates;
  final VoidCallback onConfirm;

  const _SelectionPanel({
    required this.selected,
    required this.address,
    required this.resolvingAddress,
    required this.loadingCurrentLocation,
    required this.onUseCurrentLocation,
    required this.onEnterCoordinates,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('lostReport.tapToSelect'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              selected == null
                  ? l10n.t('common.locationNotSet')
                  : '${selected!.latitude.toStringAsFixed(6)}, '
                      '${selected!.longitude.toStringAsFixed(6)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (resolvingAddress) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (address != null && address!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                address!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      loadingCurrentLocation ? null : onUseCurrentLocation,
                  icon: loadingCurrentLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(l10n.t('lostReport.useCurrent')),
                ),
                OutlinedButton.icon(
                  onPressed: onEnterCoordinates,
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  label: Text(l10n.t('lostReport.enterCoordinates')),
                ),
                FilledButton.icon(
                  onPressed: selected == null ? null : onConfirm,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.t('common.confirm')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
