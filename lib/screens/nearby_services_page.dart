import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/theme.dart';
import '../models/nearby_place.dart';
import '../providers/nearby_healthcare_provider.dart';
import '../services/location_permission_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_card.dart';

enum _NearbyViewMode { list, map }

class NearbyServicesPage extends StatelessWidget {
  const NearbyServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NearbyHealthcareProvider()..loadLocalState(),
      child: const _NearbyServicesView(),
    );
  }
}

class _NearbyServicesView extends StatefulWidget {
  const _NearbyServicesView();

  @override
  State<_NearbyServicesView> createState() => _NearbyServicesViewState();
}

class _NearbyServicesViewState extends State<_NearbyServicesView> {
  final TextEditingController _searchController = TextEditingController();
  final LocationPermissionService _locationService =
      const LocationPermissionService();
  Timer? _searchDebounce;
  _NearbyViewMode _viewMode = _NearbyViewMode.list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapLocation();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapLocation() async {
    final result = await _locationService.requestCurrentPosition();
    if (!mounted) return;

    if (result.isGranted && result.position != null) {
      await context
          .read<NearbyHealthcareProvider>()
          .setCurrentPosition(result.position!);
      return;
    }

    await _handleLocationIssue(result);
  }

  Future<void> _handleLocationIssue(LocationAccessResult result) async {
    if (!mounted) return;

    final title = switch (result.status) {
      LocationAccessStatus.serviceDisabled => 'Location Services',
      LocationAccessStatus.denied => 'Location Permission',
      LocationAccessStatus.deniedForever => 'Location Permission',
      LocationAccessStatus.unavailable => 'Location Unavailable',
      LocationAccessStatus.granted => 'Location',
    };

    final message = switch (result.status) {
      LocationAccessStatus.serviceDisabled =>
        'Turn on location services to find healthcare options around you.',
      LocationAccessStatus.denied =>
        'Medical Vault uses your location to sort hospitals, clinics, pharmacies, and ambulances by distance.',
      LocationAccessStatus.deniedForever =>
        'Location permission is blocked. Open app settings to allow access.',
      LocationAccessStatus.unavailable => result.message.isNotEmpty
          ? result.message
          : 'Unable to detect location.',
      LocationAccessStatus.granted => result.message,
    };

    final actionLabel = switch (result.status) {
      LocationAccessStatus.serviceDisabled => 'Open Location Settings',
      LocationAccessStatus.denied => 'Try Again',
      LocationAccessStatus.deniedForever => 'Open App Settings',
      LocationAccessStatus.unavailable => 'Try Again',
      LocationAccessStatus.granted => 'OK',
    };

    final shouldAct = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Not Now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldAct) return;

    if (result.status == LocationAccessStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else if (result.status == LocationAccessStatus.deniedForever) {
      await _locationService.openAppSettings();
    }

    if (!mounted) return;
    await _bootstrapLocation();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final provider = context.read<NearbyHealthcareProvider>();
      provider.setSearchQuery(value);
      provider.saveRecentSearch(value);
    });
  }

  Future<void> _callNumber(String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Unable to open dialer.');
    }
  }

  Future<void> _openInMaps(NearbyPlace place) async {
    final uri = place.mapsUrl != null && place.mapsUrl!.trim().isNotEmpty
        ? Uri.parse(place.mapsUrl!)
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${place.latitude},${place.longitude}',
            'query_place_id': place.placeId,
          });

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Unable to open Google Maps.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Healthcare Services'),
        actions: [
          Consumer<NearbyHealthcareProvider>(
            builder: (context, provider, _) {
              return IconButton(
                tooltip: 'Refresh',
                onPressed: provider.loading ? null : provider.refresh,
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<NearbyHealthcareProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Column(
                    children: [
                      _buildEmergencySection(provider),
                      const SizedBox(height: 12),
                      _buildSearchAndFilters(provider),
                      _buildRecentSearches(provider),
                      const SizedBox(height: 10),
                      _buildCategoryCards(provider),
                      const SizedBox(height: 10),
                      _buildViewToggle(),
                      _buildStatus(provider),
                    ],
                  ),
                ),
                Expanded(
                  child: _viewMode == _NearbyViewMode.list
                      ? _buildResultsList(provider)
                      : _NearbyMapView(
                          places: provider.filteredPlaces,
                          userPosition: provider.position,
                          category: provider.selectedCategory,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmergencySection(NearbyHealthcareProvider provider) {
    return CustomCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadii.small,
      softShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Emergency Assistance',
            variant: AppTextVariant.subtitle,
            fontWeight: FontWeight.w800,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: FilledButton.icon(
                      onPressed: () => _callNumber('108'),
                      icon: const Icon(Icons.local_phone_rounded, size: 18),
                      label: const Text('108 Ambulance'),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _callNumber('112'),
                      icon: const Icon(Icons.emergency_rounded, size: 18),
                      label: const Text('112 Emergency'),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        provider.selectCategory(NearbyPlaceCategory.ambulances);
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 18),
                      label: const Text('Nearby'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(NearbyHealthcareProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: provider.saveRecentSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name, area, address',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Filters',
          onPressed: () => _showFilterSheet(provider),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }

  Widget _buildRecentSearches(NearbyHealthcareProvider provider) {
    if (_searchController.text.trim().isNotEmpty ||
        provider.recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: provider.recentSearches.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final query = provider.recentSearches[index];
            return ActionChip(
              label: Text(query),
              onPressed: () {
                _searchController.text = query;
                provider.setSearchQuery(query);
                provider.saveRecentSearch(query);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCards(NearbyHealthcareProvider provider) {
    const categories = NearbyPlaceCategory.values;
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == provider.selectedCategory;
          return SizedBox(
            width: category == NearbyPlaceCategory.medicalStores ? 154 : 126,
            child: CustomCard(
              onTap: () => provider.selectCategory(category),
              padding: const EdgeInsets.all(12),
              radius: AppRadii.small,
              softShadow: selected,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selected ? 1.4 : 1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _categoryIcon(category),
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    category.label,
                    variant: AppTextVariant.caption,
                    fontWeight: FontWeight.w800,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_NearbyViewMode>(
        segments: const [
          ButtonSegment(
            value: _NearbyViewMode.list,
            icon: Icon(Icons.format_list_bulleted_rounded, size: 18),
            label: Text('List'),
          ),
          ButtonSegment(
            value: _NearbyViewMode.map,
            icon: Icon(Icons.map_rounded, size: 18),
            label: Text('Map'),
          ),
        ],
        selected: {_viewMode},
        onSelectionChanged: (selection) {
          setState(() {
            _viewMode = selection.first;
          });
        },
      ),
    );
  }

  Widget _buildStatus(NearbyHealthcareProvider provider) {
    final chips = <Widget>[];
    if (provider.usingCache) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.offline_bolt_rounded, size: 16),
          label: Text(provider.usingStaleCache ? 'Cached fallback' : 'Cached'),
        ),
      );
    }
    if (provider.minimumRating > 0) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.star_rounded, size: 16),
          label: Text('${provider.minimumRating.toStringAsFixed(1)}+'),
        ),
      );
    }
    if (provider.openNowOnly) {
      chips.add(
        const Chip(
          avatar: Icon(Icons.schedule_rounded, size: 16),
          label: Text('Open now'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
        if (provider.message.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppText(
              provider.message,
              variant: AppTextVariant.caption,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildResultsList(NearbyHealthcareProvider provider) {
    final places = provider.visiblePlaces;
    final totalCount = provider.filteredPlaces.length;

    if (provider.loading && places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (places.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Center(
              child: AppText(
                'No services found for these filters.',
                variant: AppTextVariant.body,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 220) {
            provider.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: places.length + 1,
          itemBuilder: (context, index) {
            if (index == places.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 18),
                child: Center(
                  child: provider.hasMoreVisiblePlaces
                      ? TextButton.icon(
                          onPressed: provider.loadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text('Show more of $totalCount'),
                        )
                      : AppText(
                          'Showing $totalCount result${totalCount == 1 ? '' : 's'}',
                          variant: AppTextVariant.caption,
                          fontWeight: FontWeight.w700,
                        ),
                ),
              );
            }
            return _buildPlaceCard(provider, places[index]);
          },
        ),
      ),
    );
  }

  Widget _buildPlaceCard(
    NearbyHealthcareProvider provider,
    NearbyPlace place,
  ) {
    final status = _openStatusLabel(place);
    final statusColor = place.openStatusKnown
        ? (place.openNow ? Colors.green.shade700 : Colors.red.shade600)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final phone = place.phoneNumber?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        radius: AppRadii.small,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(_categoryIcon(provider.selectedCategory)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        place.name,
                        variant: AppTextVariant.body,
                        fontWeight: FontWeight.w800,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        place.address.isEmpty
                            ? 'Address unavailable'
                            : place.address,
                        variant: AppTextVariant.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  icon: Icons.near_me_rounded,
                  label: '${place.distanceKm.toStringAsFixed(2)} km',
                ),
                _InfoPill(
                  icon: Icons.star_rounded,
                  label: place.rating > 0
                      ? place.rating.toStringAsFixed(1)
                      : 'Not rated',
                ),
                _InfoPill(
                  icon: Icons.schedule_rounded,
                  label: status,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: phone.isEmpty ? 'Phone unavailable' : 'Call',
                  onPressed: phone.isEmpty ? null : () => _callNumber(phone),
                  icon: const Icon(Icons.call_rounded),
                ),
                IconButton(
                  tooltip: 'Open in Google Maps',
                  onPressed: () => _openInMaps(place),
                  icon: const Icon(Icons.map_rounded),
                ),
                IconButton(
                  tooltip: provider.isFavorite(place)
                      ? 'Remove favorite'
                      : 'Save favorite',
                  onPressed: () => provider.toggleFavorite(place),
                  icon: Icon(
                    provider.isFavorite(place)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
                const Spacer(),
                AppText(
                  provider.selectedCategory.singularLabel,
                  variant: AppTextVariant.caption,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(NearbyHealthcareProvider provider) async {
    var radiusKm = provider.radiusKm;
    var minimumRating = provider.minimumRating;
    var openNowOnly = provider.openNowOnly;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Filters',
                    variant: AppTextVariant.subtitle,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Distance: ${radiusKm.toStringAsFixed(0)} km',
                    variant: AppTextVariant.body,
                    fontWeight: FontWeight.w700,
                  ),
                  Slider(
                    min: 1,
                    max: 30,
                    divisions: 29,
                    value: radiusKm,
                    label: '${radiusKm.toStringAsFixed(0)} km',
                    onChanged: (value) {
                      setSheetState(() => radiusKm = value);
                    },
                  ),
                  AppText(
                    minimumRating <= 0
                        ? 'Rating: Any'
                        : 'Rating: ${minimumRating.toStringAsFixed(1)}+',
                    variant: AppTextVariant.body,
                    fontWeight: FontWeight.w700,
                  ),
                  Slider(
                    min: 0,
                    max: 5,
                    divisions: 10,
                    value: minimumRating,
                    label: minimumRating <= 0
                        ? 'Any'
                        : '${minimumRating.toStringAsFixed(1)}+',
                    onChanged: (value) {
                      setSheetState(() => minimumRating = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open Now'),
                    value: openNowOnly,
                    onChanged: (value) {
                      setSheetState(() => openNowOnly = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            radiusKm = 10;
                            minimumRating = 0;
                            openNowOnly = false;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await provider.updateFilters(
                            radiusKm: radiusKm,
                            minimumRating: minimumRating,
                            openNowOnly: openNowOnly,
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _categoryIcon(NearbyPlaceCategory category) {
    return switch (category) {
      NearbyPlaceCategory.hospitals => Icons.local_hospital_rounded,
      NearbyPlaceCategory.clinics => Icons.medical_services_rounded,
      NearbyPlaceCategory.medicalStores => Icons.local_pharmacy_rounded,
      NearbyPlaceCategory.ambulances => Icons.emergency_rounded,
    };
  }

  String _openStatusLabel(NearbyPlace place) {
    if (!place.openStatusKnown) return 'Hours unavailable';
    return place.openNow ? 'Open now' : 'Closed';
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: resolvedColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: resolvedColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyMapView extends StatefulWidget {
  const _NearbyMapView({
    required this.places,
    required this.userPosition,
    required this.category,
  });

  final List<NearbyPlace> places;
  final Position? userPosition;
  final NearbyPlaceCategory category;

  @override
  State<_NearbyMapView> createState() => _NearbyMapViewState();
}

class _NearbyMapViewState extends State<_NearbyMapView> {
  GoogleMapController? _controller;
  double _zoom = 12;

  LatLng? get _userLatLng {
    final position = widget.userPosition;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  void didUpdateWidget(covariant _NearbyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.places, widget.places) ||
        oldWidget.userPosition != widget.userPosition) {
      _scheduleFitBounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _userLatLng ??
        (widget.places.isNotEmpty
            ? LatLng(
                widget.places.first.latitude, widget.places.first.longitude)
            : const LatLng(20.5937, 78.9629));

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: _userLatLng == null && widget.places.isEmpty ? 4.5 : 12,
      ),
      myLocationEnabled: _userLatLng != null,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: _buildMarkers(),
      onMapCreated: (controller) {
        _controller = controller;
        _scheduleFitBounds();
      },
      onCameraMove: (position) {
        final wasClustered = _shouldCluster(_zoom);
        final shouldCluster = _shouldCluster(position.zoom);
        _zoom = position.zoom;
        if (wasClustered != shouldCluster) {
          setState(() {});
        }
      },
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final userLatLng = _userLatLng;
    if (userLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: userLatLng,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your location'),
        ),
      );
    }

    if (_shouldCluster(_zoom)) {
      markers.addAll(_buildClusterMarkers());
      return markers;
    }

    for (final place in widget.places) {
      markers.add(
        Marker(
          markerId: MarkerId(place.placeId),
          position: LatLng(place.latitude, place.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHue(widget.category),
          ),
          infoWindow: InfoWindow(
            title: place.name,
            snippet:
                '${place.distanceKm.toStringAsFixed(2)} km | ${place.rating > 0 ? place.rating.toStringAsFixed(1) : 'Not rated'}',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Marker> _buildClusterMarkers() {
    final scale = _zoom < 10
        ? 14.0
        : _zoom < 12
            ? 28.0
            : 56.0;
    final clusters = <String, List<NearbyPlace>>{};
    for (final place in widget.places) {
      final key =
          '${(place.latitude * scale).floor()}:${(place.longitude * scale).floor()}';
      clusters.putIfAbsent(key, () => <NearbyPlace>[]).add(place);
    }

    final markers = <Marker>{};
    clusters.forEach((key, places) {
      if (places.length == 1) {
        final place = places.first;
        markers.add(
          Marker(
            markerId: MarkerId(place.placeId),
            position: LatLng(place.latitude, place.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _markerHue(widget.category),
            ),
            infoWindow: InfoWindow(title: place.name),
          ),
        );
        return;
      }

      final latitude =
          places.map((place) => place.latitude).reduce((a, b) => a + b) /
              places.length;
      final longitude =
          places.map((place) => place.longitude).reduce((a, b) => a + b) /
              places.length;
      final target = LatLng(latitude, longitude);
      markers.add(
        Marker(
          markerId: MarkerId('cluster_$key'),
          position: target,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: '${places.length} services',
            snippet: widget.category.label,
          ),
          onTap: () {
            _controller?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: target,
                  zoom: math.min(_zoom + 2.2, 18),
                ),
              ),
            );
          },
        ),
      );
    });

    return markers;
  }

  bool _shouldCluster(double zoom) {
    return widget.places.length > 12 && zoom < 13;
  }

  double _markerHue(NearbyPlaceCategory category) {
    return switch (category) {
      NearbyPlaceCategory.hospitals => BitmapDescriptor.hueRed,
      NearbyPlaceCategory.clinics => BitmapDescriptor.hueGreen,
      NearbyPlaceCategory.medicalStores => BitmapDescriptor.hueOrange,
      NearbyPlaceCategory.ambulances => BitmapDescriptor.hueRose,
    };
  }

  void _scheduleFitBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  Future<void> _fitBounds() async {
    final controller = _controller;
    if (controller == null) return;

    final points = <LatLng>[
      if (_userLatLng != null) _userLatLng!,
      ...widget.places.map((place) => LatLng(place.latitude, place.longitude)),
    ];
    if (points.isEmpty) return;

    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: points.first, zoom: 14),
          ),
        );
        return;
      }

      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLng = points.first.longitude;
      var maxLng = points.first.longitude;
      for (final point in points.skip(1)) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          64,
        ),
      );
    } catch (_) {
      // Map layout can reject bounds before the first frame is fully measured.
    }
  }
}
