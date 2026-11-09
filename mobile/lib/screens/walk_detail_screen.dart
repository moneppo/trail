import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/walk.dart';
import '../services/route_matcher.dart';
import '../services/supabase_service.dart';
import '../services/unmapped_runs.dart';
import '../theme/settings_controller.dart';
import '../theme/trail_theme.dart';
import '../utils/format.dart';
import '../widgets/trail_icons.dart';
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
  final _mapController = MapController();
  // The map's rotation in degrees, for the compass.
  final _bearing = ValueNotifier<double>(0);

  List<LatLng>? _raw;
  MatchResult? _snapped;
  List<SubmittedTrail> _trails = [];
  String? _loadError;

  // Set only when matching to streets failed and the recorded route is shown.
  String? _snapNote;

  // Whether the legend pop-out is open.
  bool _showInfo = false;

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
    _bearing.dispose();
    _mapController.dispose();
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
        return stored;
      }
    } catch (e) {
      debugPrint('[WalkDetail] $id: reading snapped route failed: $e');
    }

    final result = await RouteMatcher().match(raw);
    debugPrint('[WalkDetail] $id: ${result.describe()}');
    // Only store a match that ran to completion; a failed one is retried the
    // next time the walk is opened.
    if (result.complete) {
      try {
        await _service.saveSnappedRoute(id, result);
        debugPrint('[WalkDetail] $id: saved ${raw.length} snapped points');
      } catch (e) {
        debugPrint('[WalkDetail] $id: saving snapped route failed: $e');
      }
    } else if (mounted) {
      setState(
        () => _snapNote = 'Couldn\'t match this walk to streets, so the recorded route is shown.',
      );
    }
    return result;
  }

  bool _overlapsTrail(int start, int end) =>
      _trails.any((t) => start <= t.end && end >= t.start);

  /// Unmapped runs that haven't been submitted yet; these are the tappable
  /// dashed sections.
  List<(int, int)> get _gaps {
    final snapped = _snapped;
    if (snapped == null) return const [];
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
      setState(
        () => _submitError = 'That stretch overlaps one you already submitted.',
      );
      return;
    }
    try {
      await _service.submitUntrackedTrail(widget.walk.id, start, end);
      if (!mounted) return;
      setState(() {
        _trails = [..._trails, SubmittedTrail(start, end)];
        _selection = null;
        _submitError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _submitError = 'Couldn\'t submit: $e');
    }
  }

  List<LatLng> _slice(List<LatLng> route, int start, int end) => route.sublist(
    start.clamp(0, route.length),
    (end + 1).clamp(0, route.length),
  );

  /// Route segments between the unmapped gaps, drawn as solid lines.
  List<Polyline> _solidSegments(
    TrailColors c,
    List<LatLng> route,
    List<(int, int)> gaps,
  ) {
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
    TrailColors c,
    List<LatLng> points,
    double width,
    Color color,
  ) => Polyline(
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
    final loading =
        _snapped == null && _loadError == null && (_raw?.isNotEmpty ?? false);
    // Rebuild when the distance unit changes.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(context, c)),
            if (_showInfo)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showInfo = false),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FloatingIconButton(
                      icon: TrailIcon.back,
                      semanticLabel: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTitleCard(context, c)),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: _bearing,
                          builder: (_, bearing, _) => Compass(
                            size: 56,
                            bearing: bearing,
                            onTap: () => _mapController.rotate(0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingIconButton(
                          icon: TrailIcon.info,
                          semanticLabel: 'Map key',
                          onPressed: () =>
                              setState(() => _showInfo = !_showInfo),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_showInfo)
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 136, 12, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _buildInfo(c),
                    ),
                  ),
                ),
              ),
            if (loading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.inkSoft, width: strokeLine),
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_selection != null && _snapped != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildPanel(context, c),
              ),
          ],
        ),
      ),
    );
  }

  /// The walk's friendly date and time as a title, its distance beneath.
  Widget _buildTitleCard(BuildContext context, TrailColors c) {
    final walk = widget.walk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.inkSoft, width: strokeLine),
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            friendlyDateTime(context, walk.startedAt),
            style: TrailText.titleMd(c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${formatDistance(walk.distanceMeters, settings.units)}'
            ' · ${formatDuration(Duration(seconds: walk.durationSeconds))}',
            style: TrailText.data(c).copyWith(color: c.inkSoft, fontSize: 14),
          ),
          if (_snapNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _snapNote!,
                style: TrailText.caption(c),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, TrailColors c) {
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load this walk: $_loadError',
          style: TrailText.error(c),
        ),
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

    // The route is only drawn once it has been snapped (or matching failed and
    // the recorded route stands in), so the unsnapped line never flashes up
    // first. The map still fits to the recorded points meanwhile.
    final snapped = _snapped;
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
          border: Border.all(color: c.ink, width: strokeMarker),
        ),
        child: filled
            ? Center(
                child: Container(
                  width: size / 2.4,
                  height: size / 2.4,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        backgroundColor: c.paper,
        // Two-finger rotation turns the map and the compass with it.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapEvent: (event) {
          // Only notify on a real change: this also fires while the map is
          // first laid out.
          if (_bearing.value != event.camera.rotation) {
            _bearing.value = event.camera.rotation;
          }
        },
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
        if (snapped != null) ...[
          PolylineLayer(polylines: _solidSegments(c, route, gaps)),
          PolylineLayer(
            polylines: [
              for (final t in _trails)
                _penLine(
                  c,
                  _slice(route, t.start, t.end),
                  strokeTrail,
                  t.accepted ? c.accepted : c.candidate,
                ),
            ],
          ),
        ],
        if (sel != null && snapped != null)
          PolylineLayer(
            polylines: [
              _penLine(
                c,
                _slice(route, sel.start.round(), sel.end.round()),
                strokeTrail,
                c.candidate,
              ),
            ],
          ),
        // Tapping a dashed section opens the panel. The wide hit box makes
        // the thin dashed line easy to hit with a finger.
        if (snapped != null)
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
        if (snapped != null && route.length > 1)
          MarkerLayer(
            markers: [marker(route.first), marker(route.last, filled: true)],
          ),
        if (sel != null && snapped != null)
          MarkerLayer(
            markers: [
              for (final i in [sel.start.round(), sel.end.round()])
                marker(route[i], size: 26),
            ],
          ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _legendEntry(
    TrailColors c,
    Color color,
    String label, {
    bool dashed = false,
    double width = strokeRoute,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 10,
          child: CustomPaint(
            painter: _SwatchPainter(color: color, dashed: dashed, width: width),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: LabelText(label)),
      ],
    );
  }

  /// The map key, opened from the info icon: what each line means, plus the
  /// hint that dashed stretches can be marked as trails.
  Widget _buildInfo(TrailColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.inkSoft, width: strokeLine),
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendEntry(c, c.route, 'On the map'),
          const SizedBox(height: 10),
          _legendEntry(c, c.unmapped, 'Unmapped', dashed: true),
          const SizedBox(height: 10),
          _legendEntry(c, c.candidate, 'Submitted route', width: strokeTrail),
          const SizedBox(height: 10),
          _legendEntry(c, c.accepted, 'Approved route', width: strokeTrail),
          const SizedBox(height: 14),
          Text(
            'Tap a dashed stretch to mark it as a trail.',
            style: TrailText.hint(c),
          ),
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
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(
          top: BorderSide(color: c.inkSoft, width: strokeLine),
          left: BorderSide(color: c.inkSoft, width: strokeLine),
          right: BorderSide(color: c.inkSoft, width: strokeLine),
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(radiusMd),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mark an untracked trail',
                  style: TrailText.titleMd(c),
                ),
              ),
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
                      border: Border.all(color: c.inkSoft, width: strokeLine),
                      borderRadius: BorderRadius.circular(radiusSm),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Row(
                        children: [
                          for (final r in runs)
                            Expanded(
                              flex: r.$2,
                              child: ColoredBox(
                                color: r.$1 ? c.route : c.unmapped,
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
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
                Text(
                  '${end - start + 1} points · '
                  '${formatShortDistance(meters, settings.units)}',
                ),
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
          TrailButton(primary: true, label: 'Submit', onPressed: _submit),
        ],
      ),
    );
  }
}

/// A short line sample for the legend: solid or dashed, round-capped.
class _SwatchPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  final double width;
  _SwatchPainter({
    required this.color,
    required this.dashed,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
      return;
    }
    var x = 2.0;
    while (x < size.width - 2) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashUnmapped[0]).clamp(0, size.width - 2), y),
        paint,
      );
      x += dashUnmapped[0] + dashUnmapped[1];
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.dashed != dashed || old.width != width;
}

/// Slider handle: a paper disc with a thin ink outline.
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
