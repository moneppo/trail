import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/walk.dart';
import '../services/route_matcher.dart';
import '../services/supabase_service.dart';
import '../services/unmapped_runs.dart';
import '../theme/trail_theme.dart';
import '../widgets/trail_widgets.dart';

/// Fewest points a submitted trail can span (about 15 m at 3 m spacing).
const _minTrailPoints = 5;

const _distance = Distance();

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
  List<Polyline> _solidSegments(
      TrailColors c, List<LatLng> route, List<(int, int)> gaps) {
    final lines = <Polyline>[];
    var from = 0;
    for (final g in [...gaps, (route.length, route.length)]) {
      final segment = _slice(route, from, g.$1);
      if (segment.length > 1) {
        lines.add(_penLine(c, segment, strokeRoute, c.route));
      }
      from = g.$2;
    }
    return lines;
  }

  /// A solid stroke with a paper halo so it separates from the roads under it.
  Polyline _penLine(
          TrailColors c, List<LatLng> points, double width, Color color) =>
      Polyline(
        points: points,
        strokeWidth: width,
        color: color,
        borderStrokeWidth: 3,
        borderColor: c.paper,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      );

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    final walk = widget.walk;
    final started = '${walk.startedAt.toLocal()}'.split('.').first;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: c.paper,
                border: Border(
                    bottom: BorderSide(color: c.ink, width: strokeBold)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SquareGlyphButton(
                        glyph: '‹',
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(walk.distanceMeters / 1000).toStringAsFixed(2)} km',
                              style: TrailText.titleMd(c),
                            ),
                            Text(
                              '$started · ${_formatDuration(walk.durationSeconds)}',
                              style: TrailText.data(c)
                                  .copyWith(color: c.inkSoft, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(child: LabelText('Snap to streets and trails')),
                      const SizedBox(width: 12),
                      TrailSwitch(
                        value: _snap,
                        semanticLabel: 'Snap to streets and trails',
                        onChanged: (v) => setState(() {
                          _snap = v;
                          _selection = null;
                        }),
                      ),
                    ],
                  ),
                  if (_snap)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _snapStatus ?? 'Matching…',
                        style: TrailText.caption(c),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildMap(context, c)),
                  const Positioned(top: 12, right: 12, child: Compass(size: 56)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _selection != null
                        ? _buildPanel(context, c)
                        : _buildLegend(context, c),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, TrailColors c) {
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load this walk: $_loadError',
            style: TrailText.error(c)),
      );
    }
    final raw = _raw;
    if (raw == null) return const Center(child: CircularProgressIndicator());
    if (raw.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No route recorded.', style: TrailText.caption(c)),
      );
    }

    final snapped = _snap ? _snapped : null;
    final route = snapped?.route ?? raw;
    final gaps = _gaps;
    final sel = _selection;

    Marker marker(LatLng at, {bool filled = false, double size = 22}) => Marker(
          point: at,
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(
              color: c.paper,
              shape: BoxShape.circle,
              border: Border.all(color: c.ink, width: strokeBold),
            ),
            child: filled
                ? Center(
                    child: Container(
                      width: size / 2.4,
                      height: size / 2.4,
                      decoration:
                          BoxDecoration(color: c.ink, shape: BoxShape.circle),
                    ),
                  )
                : null,
          ),
        );

    return FlutterMap(
      options: MapOptions(
        backgroundColor: c.paper,
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
        // The colored street tiles are filtered down to ink on paper.
        ColorFiltered(
          colorFilter: inkTileFilter(Theme.of(context).brightness),
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.moneppo.trail',
          ),
        ),
        if (snapped == null)
          PolylineLayer(polylines: [_penLine(c, route, strokeRoute, c.route)])
        else
          PolylineLayer(polylines: _solidSegments(c, route, gaps)),
        PolylineLayer(polylines: [
          for (final t in _trails)
            _penLine(c, _slice(route, t.$1, t.$2), strokeTrail, c.candidate),
        ]),
        if (sel != null)
          PolylineLayer(polylines: [
            _penLine(c, _slice(route, sel.start.round(), sel.end.round()),
                strokeTrail, c.candidate),
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
                  strokeWidth: strokeRoute,
                  color: c.unmapped,
                  pattern: StrokePattern.dashed(segments: dashUnmapped),
                  hitValue: i,
                ),
            ],
          ),
        ),
        if (route.length > 1)
          MarkerLayer(markers: [
            marker(route.first),
            marker(route.last, filled: true),
          ]),
        if (sel != null)
          MarkerLayer(markers: [
            for (final i in [sel.start.round(), sel.end.round()])
              marker(route[i], size: 26),
          ]),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _legendEntry(TrailColors c, Color color, String label,
      {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 10,
          child: CustomPaint(
              painter: _SwatchPainter(color: color, dashed: dashed)),
        ),
        const SizedBox(width: 8),
        LabelText(label),
      ],
    );
  }

  /// What the map's lines mean, plus the hint that dashed stretches are tappable.
  Widget _buildLegend(BuildContext context, TrailColors c) {
    if (!_snap || _snapped == null) return const SizedBox.shrink();
    final gaps = _gaps;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(top: BorderSide(color: c.ink, width: strokeBold)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _legendEntry(c, c.route, 'On the map'),
              _legendEntry(c, c.unmapped, 'Unmapped', dashed: true),
            ],
          ),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tap a dashed stretch to mark it as a trail.',
                style: TrailText.hint(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, TrailColors c) {
    final snapped = _snapped!;
    final statuses = snapped.statuses;
    final route = snapped.route;
    final sel = _selection!;
    final start = sel.start.round();
    final end = sel.end.round();

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

    var meters = 0.0;
    for (var i = start + 1; i <= end && i < route.length; i++) {
      meters += _distance.as(LengthUnit.Meter, route[i - 1], route[i]);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(
          top: BorderSide(color: c.ink, width: strokeBold),
          left: BorderSide(color: c.ink, width: strokeBold),
          right: BorderSide(color: c.ink, width: strokeBold),
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(radiusMd)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Mark an untracked trail',
                      style: TrailText.titleMd(c))),
              const SizedBox(width: 16),
              SquareGlyphButton(
                glyph: '×',
                semanticLabel: 'Close',
                onPressed: _closePanel,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.paperShade,
                      border: Border.all(color: c.ink, width: strokeLine),
                      borderRadius: BorderRadius.circular(radiusSm),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Row(children: [
                        for (final r in runs)
                          Expanded(
                            flex: r.$2,
                            child: ColoredBox(
                              color: r.$1 ? c.route : c.unmapped,
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 11,
                    activeTrackColor: c.candidate,
                    inactiveTrackColor: Colors.transparent,
                    overlayShape: SliderComponentShape.noOverlay,
                    rangeThumbShape: _TrailThumbShape(c),
                    rangeTrackShape: const RectangularRangeSliderTrackShape(),
                  ),
                  child: RangeSlider(
                    min: 0,
                    max: (statuses.length - 1).toDouble(),
                    values: sel,
                    onChanged: (v) {
                      var s = v.start.roundToDouble();
                      var e = v.end.roundToDouble();
                      if (e - s < _minTrailPoints) {
                        // Keep the handle that wasn't dragged in place.
                        if (s != sel.start.roundToDouble()) {
                          s = e - _minTrailPoints;
                        } else {
                          e = s + _minTrailPoints;
                        }
                      }
                      setState(() {
                        _selection = RangeValues(
                          s.clamp(0, statuses.length - 1.0),
                          e.clamp(0, statuses.length - 1.0),
                        );
                        _submitError = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: TrailText.data(c),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Point ${start + 1}'),
                Text('${end - start + 1} points · ${meters.round()} m'),
                Text('Point ${end + 1}'),
              ],
            ),
          ),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_submitError!, style: TrailText.error(c)),
            ),
          const SizedBox(height: 16),
          PlateButton(primary: true, label: 'Submit', onPressed: _submit),
        ],
      ),
    );
  }
}

/// A short line sample for the legend: solid or dashed, round-capped.
class _SwatchPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _SwatchPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeRoute
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
      return;
    }
    var x = 2.0;
    while (x < size.width - 2) {
      canvas.drawLine(Offset(x, y),
          Offset((x + dashUnmapped[0]).clamp(0, size.width - 2), y), paint);
      x += dashUnmapped[0] + dashUnmapped[1];
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Slider handle: a paper disc with an ink outline and a hard offset shadow.
class _TrailThumbShape extends RangeSliderThumbShape {
  final TrailColors colors;
  const _TrailThumbShape(this.colors);

  static const _radius = 14.0;

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
    final radius = _radius - strokeBold / 2;
    canvas.drawCircle(center + const Offset(2, 2), radius,
        Paint()..color = colors.ink);
    canvas.drawCircle(center, radius, Paint()..color = colors.paper);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = colors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeBold,
    );
  }
}
