import 'route_matcher.dart';

/// Shortest run of consecutive unmapped points worth suggesting as a trail
/// (about 45 m at the 3 m recording interval).
const minUnmappedRun = 15;

/// Runs of consecutive points that aren't on a mapped path, as inclusive
/// (start, end) index pairs.
List<(int, int)> findUnmappedRuns(List<MatchStatus> statuses) {
  final runs = <(int, int)>[];
  int? start;
  for (var i = 0; i <= statuses.length; i++) {
    final unmapped = i < statuses.length && statuses[i] != MatchStatus.matched;
    if (unmapped) {
      start ??= i;
    } else if (start != null) {
      if (i - start >= minUnmappedRun) runs.add((start, i - 1));
      start = null;
    }
  }
  return runs;
}
