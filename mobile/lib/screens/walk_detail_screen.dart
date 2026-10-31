import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/walk.dart';
import '../services/route_matcher.dart';
import '../services/supabase_service.dart';
import '../services/unmapped_runs.dart';

const _matchedColor = Color(0xFF1D9E75);
const _unmappedColor = Color(0xFFBA7517);
const _trailColor = Color(0xFF534AB7);

/// Fewest points a submitted trail can span (about 15 m at 3 m spacing).
const _minTrailPoints = 5;

class WalkDetailScreen extends StatefulWidget {
  final Walk walk;

  const WalkDetailScreen({super.key, required this.walk});

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  final _service = SupabaseService();
  final _gapHits = ValueNotifier<LayerHitResult<int>?>(null);

  List<LatLng>? _raw;
  MatchResult? _snapped;
  List<(int, int)> _trails = [];
  String? _loadError;

  bool _snap = true;
  String? _snapStatus;

  // The stretch being adjusted in the panel, as point indices.
  RangeValues? _selection;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gapHits.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final points = await _service.fetchWalkPoints(widget.walk.id);
      final raw = points.map((p) => LatLng(p.lat, p.lng)).toList();
      if (!mounted) return;
      setState(() => _raw = raw);

      final snapped = await _snapRoute(raw);
      final trails = await _service.fetchUntrackedTrails(widget.walk.id);
      if (!mounted) return;
      setState(() {
        _snapped = snapped;
        _trails = trails;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<MatchResult> _snapRoute(List<LatLng> raw) async {
    final id = widget.walk.id;
    try {
      final stored = await _service.fetchSnappedRoute(id);
      if (stored != null && stored.route.length == raw.length) {
        debugPrint('[WalkDetail] $id: snapped route loaded from database');
        _setStatus('Snapped route loaded from database');
        return stored;
      }
    } catch (e) {
      debugPrint('[WalkDetail] $id: reading snapped route failed: $e');
    }

    final result = await RouteMatcher().match(raw);
    var status = result.describe();
    // Only store a match that ran to completion; a failed one is retried the
    // next time the walk is opened.
    if (result.complete) {
      try {
        await _service.saveSnappedRoute(id, result);
        debugPrint('[WalkDetail] $id: saved ${raw.length} snapped points');
        status += ' (saved)';
      } catch (e) {
        debugPrint('[WalkDetail] $id: saving snapped route failed: $e');
        status += ' (could not save: $e)';
      }
    }
    _setStatus(status);
    return result;
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

  bool _overlapsTrail(int start, int end) =>
      _trails.any((t) => start <= t.$2 && end >= t.$1);

  /// Unmapped runs that haven't been submitted yet; these are the tappable
  /// dashed sections.
  List<(int, int)> get _gaps {
    final snapped = _snapped;
    if (!_snap || snapped == null) return const [];
    return findUnmappedRuns(snapped.statuses)
        .where((g) => !_overlapsTrail(g.$1, g.$2))
        .toList();
  }

  void _openGap((int, int) gap) {
    setState(() {
      _selection = RangeValues(gap.$1.toDouble(), gap.$2.toDouble());
      _submitError = null;
    });
  }

  void _closePanel() => setState(() {
        _selection = null;
        _submitError = null;
      });

  Future<void> _submit() async {
    final sel = _selection!;
    final start = sel.start.round();
    final end = sel.end.round();
    if (_overlapsTrail(start, end)) {
      setState(() =>
          _submitError = 'That stretch overlaps one you already submitted.');
      return;
    }
    try {
      await _service.submitUntrackedTrail(widget.walk.id, start, end);
      if (!mounted) return;
      setState(() {
        _trails = [..._trails, (start, end)];
        _selection = null;
        _submitError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _submitError = 'Couldn\'t submit: $e');
    }
  }

  List<LatLng> _slice(List<LatLng> route, int start, int end) => route.sublist(
      start.clamp(0, route.length), (end + 1).clamp(0, route.length));

  /// Route segments between the unmapped gaps, drawn as solid lines.
  List<Polyline> _solidSegments(List<LatLng> route, List<(int, int)> gaps) {
    final lines = <Polyline>[];
    var from = 0;
    for (final g in [...gaps, (route.length, route.length)]) {
      final segment = _slice(route, from, g.$1);
      if (segment.length > 1) {
        lines.add(
            Polyline(points: segment, strokeWidth: 4, color: _matchedColor));
      }
      from = g.$2;
    }
    return lines;
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
            onChanged: (v) => setState(() {
              _snap = v;
              _selection = null;
            }),
          ),
          if (_snap)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _snapStatus ?? 'Matching…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(child: _buildMap(context)),
          if (_selection != null) _buildPanel(context),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    if (_loadError != null) return Center(child: Text('Error: $_loadError'));
    final raw = _raw;
    if (raw == null) return const Center(child: CircularProgressIndicator());
    if (raw.isEmpty) return const Center(child: Text('No route recorded.'));

    final snapped = _snap ? _snapped : null;
    final route = snapped?.route ?? raw;
    final gaps = _gaps;
    final sel = _selection;

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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moneppo.trail',
        ),
        if (snapped == null)
          PolylineLayer(polylines: [
            Polyline(
              points: route,
              strokeWidth: 5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ])
        else
          PolylineLayer(polylines: _solidSegments(route, gaps)),
        PolylineLayer(polylines: [
          for (final t in _trails)
            Polyline(
                points: _slice(route, t.$1, t.$2),
                strokeWidth: 6,
                color: _trailColor),
        ]),
        if (sel != null)
          PolylineLayer(polylines: [
            Polyline(
              points: _slice(route, sel.start.round(), sel.end.round()),
              strokeWidth: 14,
              color: _trailColor.withValues(alpha: 0.4),
            ),
          ]),
        // Tapping a dashed section opens the panel. The wide hit box makes
        // the thin dashed line easy to hit with a finger.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final hit = _gapHits.value?.hitValues.firstOrNull;
            if (hit != null && hit < gaps.length) _openGap(gaps[hit]);
          },
          child: PolylineLayer<int>(
            hitNotifier: _gapHits,
            minimumHitbox: 24,
            polylines: [
              for (var i = 0; i < gaps.length; i++)
                Polyline<int>(
                  points: _slice(route, gaps[i].$1 - 1, gaps[i].$2 + 1),
                  strokeWidth: 4,
                  color: _unmappedColor,
                  pattern: StrokePattern.dashed(segments: const [8, 8]),
                  hitValue: i,
                ),
            ],
          ),
        ),
        if (sel != null)
          MarkerLayer(markers: [
            for (final i in [sel.start.round(), sel.end.round()])
              Marker(
                point: route[i],
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _trailColor, width: 2.5),
                  ),
                ),
              ),
          ]),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final statuses = _snapped!.statuses;
    final sel = _selection!;
    final scheme = Theme.of(context).colorScheme;

    // Colour strip of the whole walk: mapped vs unmapped stretches.
    final runs = <(bool, int)>[];
    for (final s in statuses) {
      final mapped = s == MatchStatus.matched;
      if (runs.isNotEmpty && runs.last.$1 == mapped) {
        runs[runs.length - 1] = (mapped, runs.last.$2 + 1);
      } else {
        runs.add((mapped, 1));
      }
    }

    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: _closePanel,
                ),
              ),
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Row(children: [
                            for (final r in runs)
                              Expanded(
                                flex: r.$2,
                                child: ColoredBox(
                                  color: r.$1 ? _matchedColor : _unmappedColor,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        activeTrackColor: _trailColor.withValues(alpha: 0.35),
                        inactiveTrackColor: Colors.transparent,
                        overlayShape: SliderComponentShape.noOverlay,
                        rangeThumbShape: const _TrailThumbShape(),
                        rangeTrackShape:
                            const RectangularRangeSliderTrackShape(),
                      ),
                      child: RangeSlider(
                        min: 0,
                        max: (statuses.length - 1).toDouble(),
                        values: sel,
                        onChanged: (v) {
                          var start = v.start.roundToDouble();
                          var end = v.end.roundToDouble();
                          if (end - start < _minTrailPoints) {
                            // Keep the handle that wasn't dragged in place.
                            if (start != sel.start.roundToDouble()) {
                              start = end - _minTrailPoints;
                            } else {
                              end = start + _minTrailPoints;
                            }
                          }
                          setState(() {
                            _selection = RangeValues(
                              start.clamp(0, statuses.length - 1.0),
                              end.clamp(0, statuses.length - 1.0),
                            );
                            _submitError = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_submitError!,
                      style: TextStyle(color: scheme.error, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailThumbShape extends RangeSliderThumbShape {
  const _TrailThumbShape();

  static const _radius = 10.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, _radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..color = _trailColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
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
