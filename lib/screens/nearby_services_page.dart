import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api_service.dart';

class NearbyServicesPage extends StatefulWidget {
  const NearbyServicesPage({super.key});

  @override
  State<NearbyServicesPage> createState() => _NearbyServicesPageState();
}

class _NearbyServicesPageState extends State<NearbyServicesPage> {
  List<Map<String, dynamic>> _services = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _criticalServices = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _isCached = false;
  bool _isStale = false;
  String _message = '';
  String _lastUpdatedAt = '';

  static const List<Map<String, dynamic>> _fallbackCriticalServices = [
    {'type': 'AMBULANCE', 'name': 'Ambulance', 'phone': '108'},
    {'type': 'EMERGENCY', 'name': 'Emergency Response', 'phone': '112'},
    {'type': 'WOMEN_HELPLINE', 'name': 'Women Helpline', 'phone': '1091'},
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Future<void> _bootstrap() async {
    final cached = await ApiService.getCachedNearbyServices();
    if (cached != null && mounted) {
      setState(() {
        _services = _mapList(cached['services']);
        _criticalServices = _mapList(cached['criticalServices']);
        _lastUpdatedAt =
            (cached['lastUpdatedAt'] ?? cached['cachedAt'] ?? '').toString();
        _isCached = true;
        _isStale = ApiService.isNearbyCacheStale(cached);
        _loading = false;
      });
    }
    await _fetchLive();
  }

  Future<Position?> _resolvePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  Future<void> _fetchLive() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final position = await _resolvePosition();
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message =
            'Location permission is unavailable. Showing cached or emergency data.';
        if (_criticalServices.isEmpty) {
          _criticalServices = _fallbackCriticalServices;
        }
      });
      return;
    }

    final response = await ApiService.fetchNearbyServices(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!mounted) return;

    final success = response['success'] == true;
    if (!success) {
      setState(() {
        _loading = false;
        _message = (response['message'] ?? 'Unable to load nearby services')
            .toString();
        if (_criticalServices.isEmpty) {
          _criticalServices = _fallbackCriticalServices;
        }
      });
      return;
    }

    final critical = _mapList(response['criticalServices']);
    setState(() {
      _services = _mapList(response['services']);
      _criticalServices =
          critical.isNotEmpty ? critical : _fallbackCriticalServices;
      _lastUpdatedAt = (response['lastUpdatedAt'] ?? '').toString();
      _isCached = response['isCached'] == true;
      _isStale = response['isStale'] == true;
      _message = (response['message'] ?? '').toString();
      _loading = false;
    });
  }

  String _lastUpdatedText() {
    if (_lastUpdatedAt.trim().isEmpty) return 'Unknown';
    final parsed = DateTime.tryParse(_lastUpdatedAt);
    if (parsed == null) return _lastUpdatedAt;
    return parsed.toLocal().toString().split('.').first;
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    final name = (service['name'] ?? 'Service').toString();
    final distance = (service['distanceText'] ?? '').toString();
    final rating = (service['rating'] ?? '').toString();
    final availability = (service['availability'] ?? 'UNKNOWN').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.local_hospital_rounded),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${distance.isEmpty ? 'Distance NA' : distance} | Rating ${rating.isEmpty ? 'NA' : rating} | $availability',
        ),
      ),
    );
  }

  Widget _buildCriticalTile(Map<String, dynamic> contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.red.shade50,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          child: Icon(Icons.call_rounded),
        ),
        title: Text(
          (contact['name'] ?? 'Emergency Contact').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text((contact['type'] ?? 'EMERGENCY').toString()),
        trailing: Text(
          (contact['phone'] ?? '-').toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Services'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchLive,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLive,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.update_rounded, size: 16),
                  label: Text('Last updated: ${_lastUpdatedText()}'),
                ),
                if (_isCached || _isStale)
                  Chip(
                    backgroundColor: Colors.orange.shade100,
                    avatar: const Icon(Icons.offline_bolt_rounded, size: 16),
                    label: Text(_isStale ? 'Last updated data' : 'Cached data'),
                  ),
              ],
            ),
            if (_message.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _message,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text('No nearby services found right now.'),
                ),
              )
            else ...[
              const Text(
                'Hospitals, Clinics, Ambulances, Doctors',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ..._services.map(_buildServiceTile),
            ],
            const SizedBox(height: 16),
            const Text(
              'Critical Emergency Contacts',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...(_criticalServices.isNotEmpty
                    ? _criticalServices
                    : _fallbackCriticalServices)
                .map(_buildCriticalTile),
          ],
        ),
      ),
    );
  }
}
