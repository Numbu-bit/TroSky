import 'dart:math' as math;

/// The countries passengers may sign up in, as areas on the map: a port of
/// backend/app/utilities/regions.py, so the mock answers as the backend does.
///
/// Ghana's outline is Natural Earth's 1:110m border with the Volta corner by
/// Aflao added, widened by about 15 km so that border towns (Aflao, Paga,
/// Elubo, Hamile) and a phone's GPS error never turn a Ghanaian away. Places
/// just across the border, such as Lomé, also pass.
const Map<String, String> countryNames = {'GH': 'Ghana'};

/// "Ghana", or "Ghana or Togo": for messages.
String countryNamesFor(Iterable<String> countries) =>
    (countries.toList()..sort()).map((c) => countryNames[c] ?? c).join(' or ');

/// Which of [countries] the point is in, or null when it is in none of them.
String? countryAt(
  double latitude,
  double longitude,
  Iterable<String> countries,
) {
  for (final country in countries.toList()..sort()) {
    final outline = _outlines[country];
    if (outline != null && _inside(outline, longitude, latitude)) {
      return country;
    }
  }
  return null;
}

/// (longitude, latitude), anticlockwise from Keta along the coast.
const List<(double, double)> _ghana = [
  (1.0601, 5.9288),
  (-0.5076, 5.3435),
  (-1.0636, 5.0005),
  (-1.9647, 4.7105),
  (-2.8561, 4.9945),
  (-2.8107, 5.3891),
  (-3.2444, 6.2505),
  (-2.9836, 7.3797),
  (-2.5622, 8.2196),
  (-2.8275, 9.6425),
  (-2.9639, 10.3953),
  (-2.9404, 10.9627),
  (-1.2034, 11.0098),
  (-0.7616, 10.9369),
  (-0.4387, 11.0983),
  (0.0238, 11.0187),
  (-0.0498, 10.7069),
  (0.3676, 10.1912),
  (0.3659, 9.4650),
  (0.4612, 8.6772),
  (0.7120, 8.3125),
  (0.4910, 7.4117),
  (0.5704, 6.9144),
  (0.8369, 6.2800),
  // The Volta corner: the border reaches the coast at Aflao.
  (1.0500, 6.2700),
  (1.2000, 6.1000),
];

const Map<String, List<(double, double)>> _outlines = {'GH': _ghana};

/// About 15 km at Ghana's latitudes, as the backend's buffer.
const double _marginDegrees = 0.15;

/// Inside the outline, or within the margin of its edge (what the backend's
/// `Polygon.buffer(margin)` contains).
bool _inside(List<(double, double)> outline, double x, double y) {
  var inside = false;
  var nearest = double.infinity;
  for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
    final (xi, yi) = outline[i];
    final (xj, yj) = outline[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
    nearest = math.min(nearest, _distanceToSegment(x, y, xi, yi, xj, yj));
  }
  return inside || nearest <= _marginDegrees;
}

double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final t = lengthSquared == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final cx = ax + t * dx;
  final cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
