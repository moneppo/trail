import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/walk.dart';
import '../services/route_cache.dart';
import '../services/route_matcher.dart';
import '../services/supabase_service.dart';

class WalkDetailScreen extends StatefulWidget {
  final Walk walk;

  const WalkDetailScreen({super.key, required this.walk});

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  final _service = SupabaseService();
  late Future<List<LatLng>> _rawFuture;
  Future<List<LatLng>>? _snappedFuture;
  bool _snap = true;
  String? _snapStatus;

  @override
  void initState() {
    super.initState();
    _rawFuture = _service.fetchWalkPoints(widget.walk.id).then(
          (points) => points.map((p) => LatLng(p.lat, p.lng)).toList(),
        );
    _snappedFuture = _rawFuture.then(_snapRoute);
  }

  Future<List<LatLng>> _snapRoute(List<LatLng> raw) async {
    final cache = RouteCache();
    final cached = await cache.read(widget.walk.id, raw.length);
    if (cached != null) {
      debugPrint('[WalkDetail] ${widget.walk.id}: snapped route from cache');
      _setStatus('Snapped route loaded from cache');
      return cached;
    }

    final result = await RouteMatcher().match(raw);
    _setStatus(result.summary.toString());
    // Only cache a route that actually snapped; a failed or empty match
    // should be retried next time rather than remembered.
    if (result.summary.usable) await cache.write(widget.walk.id, result.route);
    return result.route;
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _snapStatus = status);
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    return Scaffold(
      appBar: AppBar(
        title: Text('${walk.startedAt.toLocal()}'.split('.').first),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  label: 'Distance',
                  value: '${(walk.distanceMeters / 1000).toStringAsFixed(2)} km',
                ),
                _Stat(
                  label: 'Duration',
                  value: _formatDuration(walk.durationSeconds),
                ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Snap to streets and trails'),
            value: _snap,
            onChanged: (v) => setState(() => _snap = v),
          ),
          if (_snap)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _snapStatus ?? 'Matching…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<LatLng>>(
              future: _snap ? _snappedFuture : _rawFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final route = snapshot.data ?? [];
                if (route.isEmpty) {
                  return const Center(child: Text('No route recorded.'));
                }
                return FlutterMap(
                  options: MapOptions(
                    initialCameraFit: route.length > 1
                        ? CameraFit.coordinates(
                            coordinates: route,
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    initialCenter: route.first,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.moneppo.trail',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route,
                          strokeWidth: 5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: route.first,
                          child: const Icon(Icons.circle,
                              color: Colors.green, size: 16),
                        ),
                        Marker(
                          point: route.last,
                          child: const Icon(Icons.flag, color: Colors.red),
                        ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
