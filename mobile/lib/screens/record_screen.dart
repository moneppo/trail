import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/live_route_snapper.dart';
import '../services/supabase_service.dart';
import '../services/unmapped_runs.dart';
import '../services/walk_tracker.dart';
import '../theme/trail_theme.dart';
import '../widgets/trail_widgets.dart';

/// How often the walk so far is snapped to streets while recording. Kept
/// slow so a long walk doesn't flood the matching server.
const _snapInterval = Duration(seconds: 30);

/// A new walk: a map with the walker's position and a Start button. Once
/// started, the map draws the route, snapped to streets about every 30 seconds.
/// Pops with `true` when a walk was saved.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _tracker = WalkTracker();
  final _service = SupabaseService();
  final _snapper = LiveRouteSnapper();
  final _mapController = MapController();
  // The map's rotation in degrees, for the compass.
  final _bearing = ValueNotifier<double>(0);

  Timer? _snapTimer;
  bool _mapReady = false;
  bool _following = true;
  bool _recording = false;
  bool _saving = false;
  String? _error;
  TrackedWalk? _unsaved;
  LiveRoute? _live;

  @override
  void initState() {
    super.initState();
    _tracker.current.addListener(_onPosition);
    _tracker.pointCount.addListener(_onPoint);
    _setUp();
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _tracker.current.removeListener(_onPosition);
    _tracker.pointCount.removeListener(_onPoint);
    _tracker.dispose();
    _bearing.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _setUp() async {
    final granted = await _tracker.ensurePermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() => _error =
          'Location permission is needed to show where you are and to record a walk.');
      return;
    }
    await _tracker.startPreview();
  }

  void _onPosition() {
    if (!mounted) return;
    setState(() {});
    final here = _tracker.current.value;
    if (_following && _mapReady && here != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _following) {
          _mapController.move(here, _mapController.camera.zoom);
        }
      });
    }
  }

  void _onPoint() {
    if (mounted && _recording) {
      setState(() => _live = _snapper.build(_tracker.track));
    }
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _following = true;
    });
    await _tracker.start();
    if (!mounted) return;
    setState(() => _recording = true);
    _snapTimer = Timer.periodic(_snapInterval, (_) => _snap());
  }

  Future<void> _snap() async {
    await _snapper.update(_tracker.track);
    if (mounted && _recording) {
      setState(() => _live = _snapper.build(_tracker.track));
    }
  }

  Future<void> _stop() async {
    _snapTimer?.cancel();
    final walk = await _tracker.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (walk == null) {
      setState(() => _error = 'No location was recorded, so there is no walk to save.');
      return;
    }
    _unsaved = walk;
    await _save();
  }

  Future<void> _save() async {
    final walk = _unsaved;
    if (walk == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.uploadWalk(walk);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this walk: $e';
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return PopScope(
      // Leaving mid-walk would lose it, so back is only available before
      // starting or when a walk failed to save.
      canPop: !_recording && !_saving && _unsaved == null,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(context, c)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_recording)
                      _RecordingChip(colors: c)
                    else if (!_saving && _unsaved == null)
                      SquareGlyphButton(
                        glyph: '‹',
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: _bearing,
                          builder: (_, bearing, _) => Compass(
                            size: 56,
                            bearing: bearing,
                            onTap: () => _mapController.rotate(0),
                          ),
                        ),
                        if (!_following)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _Pill(
                              colors: c,
                              child: TrailLink(
                                text: 'Center on me',
                                onPressed: () {
                                  setState(() => _following = true);
                                  final here = _tracker.current.value;
                                  if (here != null) {
                                    _mapController.move(
                                        here, _mapController.camera.zoom);
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSheet(context, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, TrailColors c) {
    final here = _tracker.current.value;
    if (here == null) {
      return ColoredBox(
        color: c.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Finding your location…',
              style: _error != null ? TrailText.error(c) : TrailText.caption(c),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final live = _live;
    final track = live?.route ?? const <LatLng>[];
    final gaps = live == null ? const <(int, int)>[] : findUnmappedRuns(live.statuses);

    Marker dot(LatLng at, {required bool youAreHere}) => Marker(
          point: at,
          width: youAreHere ? 30 : 22,
          height: youAreHere ? 30 : 22,
          child: Container(
            decoration: BoxDecoration(
              color: c.paper,
              shape: BoxShape.circle,
              border: Border.all(color: c.ink, width: strokeMarker),
            ),
            child: Center(
              child: Container(
                width: youAreHere ? 14 : 8,
                height: youAreHere ? 14 : 8,
                decoration: BoxDecoration(
                  color: youAreHere ? c.route : c.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        backgroundColor: c.paper,
        initialCenter: here,
        initialZoom: 17,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
        onMapReady: () => _mapReady = true,
        onMapEvent: (event) {
          if (_bearing.value != event.camera.rotation) {
            _bearing.value = event.camera.rotation;
          }
          // Dragging or pinching the map means the walker wants to look
          // around, so stop following their position.
          if (_following &&
              (event.source == MapEventSource.dragStart ||
                  event.source == MapEventSource.multiFingerGestureStart)) {
            setState(() => _following = false);
          }
        },
      ),
      children: [
        ColorFiltered(
          colorFilter: inkTileFilter(Theme.of(context).brightness),
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.moneppo.trail',
          ),
        ),
        if (track.length > 1) ..._routeLayers(c, track, gaps),
        MarkerLayer(markers: [
          if (track.isNotEmpty) dot(track.first, youAreHere: false),
          dot(here, youAreHere: true),
        ]),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  /// The walk so far: on-map stretches solid, unmapped stretches dashed.
  List<Widget> _routeLayers(
      TrailColors c, List<LatLng> route, List<(int, int)> gaps) {
    List<LatLng> slice(int start, int end) => route.sublist(
        start.clamp(0, route.length), (end + 1).clamp(0, route.length));

    final solid = <Polyline>[];
    var from = 0;
    for (final g in [...gaps, (route.length, route.length)]) {
      final segment = slice(from, g.$1);
      if (segment.length > 1) {
        solid.add(Polyline(
          points: segment,
          strokeWidth: strokeRoute,
          color: c.route,
          borderStrokeWidth: 3,
          borderColor: c.paper,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ));
      }
      from = g.$2;
    }
    return [
      PolylineLayer(polylines: solid),
      if (gaps.isNotEmpty)
        PolylineLayer(polylines: [
          for (final g in gaps)
            Polyline(
              points: slice(g.$1 - 1, g.$2 + 1),
              strokeWidth: strokeRoute,
              color: c.unmapped,
              pattern: StrokePattern.dashed(segments: dashUnmapped),
            ),
        ]),
    ];
  }

  Widget _buildSheet(BuildContext context, TrailColors c) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(
          top: BorderSide(color: c.inkSoft, width: strokeLine),
          left: BorderSide(color: c.inkSoft, width: strokeLine),
          right: BorderSide(color: c.inkSoft, width: strokeLine),
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(radiusMd)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Saving walk…',
                  style: TrailText.caption(c), textAlign: TextAlign.center),
            )
          else if (_unsaved != null) ...[
            Text(_error ?? 'This walk has not been saved yet.',
                style: TrailText.error(c)),
            const SizedBox(height: 16),
            TrailButton(primary: true, label: 'Try again', onPressed: _save),
            const SizedBox(height: 4),
            Center(
              child: TrailLink(
                text: 'Discard this walk',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ] else if (_recording) ...[
            const LabelText('Elapsed'),
            const SizedBox(height: 4),
            ValueListenableBuilder<Duration>(
              valueListenable: _tracker.duration,
              builder: (_, duration, _) => Text(
                _formatDuration(duration),
                style: TrailText.data(c).copyWith(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.08,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  label: 'Distance',
                  child: ValueListenableBuilder<double>(
                    valueListenable: _tracker.distance,
                    builder: (_, meters, _) => Text(
                      '${(meters / 1000).toStringAsFixed(2)} km',
                      style: TrailText.data(c).copyWith(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                _Stat(
                  label: 'Points',
                  child: ValueListenableBuilder<int>(
                    valueListenable: _tracker.pointCount,
                    builder: (_, count, _) => Text(
                      '$count',
                      style: TrailText.data(c).copyWith(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TrailButton(primary: true, label: 'Stop walk', onPressed: _stop),
          ] else ...[
            Text('New walk', style: TrailText.titleMd(c)),
            const SizedBox(height: 4),
            Text(
              _tracker.current.value == null
                  ? 'Waiting for your location.'
                  : 'Your position is on the map. Start when you are ready.',
              style: TrailText.caption(c),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TrailText.error(c)),
            ],
            const SizedBox(height: 16),
            TrailButton(
              primary: true,
              label: 'Start walk',
              onPressed: _tracker.current.value == null ? null : _start,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final Widget child;
  const _Stat({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [LabelText(label), const SizedBox(height: 2), child],
      );
}

class _Pill extends StatelessWidget {
  final TrailColors colors;
  final Widget child;
  const _Pill({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.paper,
          border: Border.all(color: colors.inkSoft, width: strokeLine),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        child: child,
      );
}

class _RecordingChip extends StatelessWidget {
  final TrailColors colors;
  const _RecordingChip({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.paper,
          border: Border.all(color: colors.inkSoft, width: strokeLine),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: colors.route, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const LabelText('Recording'),
          ],
        ),
      );
}
