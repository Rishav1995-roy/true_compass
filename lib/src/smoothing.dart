import 'dart:collection';

import 'angles.dart';

/// Strategy used to calm down a jittery heading.
///
/// All strategies work on the circle, so a stream that alternates between 359
/// and 1 degrees settles near 0, never near 180.
sealed class CompassSmoothing {
  const CompassSmoothing();

  /// Passes samples through untouched.
  const factory CompassSmoothing.none() = NoSmoothing;

  /// Exponential low-pass filter. [alpha] is the weight of each new sample in
  /// `(0, 1]`: small values are smooth but laggy, `1` is no smoothing.
  const factory CompassSmoothing.lowPass({double alpha}) = LowPassSmoothing;

  /// Circular mean of the last [window] samples.
  const factory CompassSmoothing.circularAverage({int window}) =
      CircularAverageSmoothing;

  /// Creates a fresh stateful filter for one stream.
  HeadingSmoother createSmoother();
}

/// No smoothing.
class NoSmoothing extends CompassSmoothing {
  /// Creates the strategy.
  const NoSmoothing();

  @override
  HeadingSmoother createSmoother() => _PassThroughSmoother();
}

/// Exponential low-pass filter; see [CompassSmoothing.lowPass].
class LowPassSmoothing extends CompassSmoothing {
  /// Creates the strategy.
  const LowPassSmoothing({this.alpha = 0.2})
      : assert(alpha > 0 && alpha <= 1, 'alpha must be in (0, 1]');

  /// Weight of each new sample.
  final double alpha;

  @override
  HeadingSmoother createSmoother() => _LowPassSmoother(alpha);
}

/// Sliding-window circular mean; see [CompassSmoothing.circularAverage].
class CircularAverageSmoothing extends CompassSmoothing {
  /// Creates the strategy.
  const CircularAverageSmoothing({this.window = 8})
      : assert(window >= 1, 'window must be at least 1');

  /// Number of samples averaged.
  final int window;

  @override
  HeadingSmoother createSmoother() => _CircularAverageSmoother(window);
}

/// A stateful filter created by [CompassSmoothing.createSmoother].
abstract class HeadingSmoother {
  /// Feeds [degrees] and returns the smoothed heading in `[0, 360)`.
  double add(double degrees);

  /// Forgets all history.
  void reset();
}

class _PassThroughSmoother implements HeadingSmoother {
  @override
  double add(double degrees) => Angles.normalize360(degrees);

  @override
  void reset() {}
}

class _LowPassSmoother implements HeadingSmoother {
  _LowPassSmoother(this.alpha);

  final double alpha;
  double? _value;

  @override
  double add(double degrees) {
    final previous = _value;
    final next = previous == null
        ? Angles.normalize360(degrees)
        // Move along the shortest arc, so 359 -> 1 goes through 0.
        : Angles.normalize360(
            previous + alpha * Angles.shortestDelta(previous, degrees),
          );
    _value = next;
    return next;
  }

  @override
  void reset() => _value = null;
}

class _CircularAverageSmoother implements HeadingSmoother {
  _CircularAverageSmoother(this.window);

  final int window;
  final Queue<double> _samples = Queue<double>();
  double _last = 0;

  @override
  double add(double degrees) {
    _samples.addLast(degrees);
    while (_samples.length > window) {
      _samples.removeFirst();
    }
    // Exactly opposite samples have no mean; keep following the latest one.
    final mean = Angles.circularMean(_samples.toList());
    _last = mean ?? Angles.normalize360(degrees);
    return _last;
  }

  @override
  void reset() => _samples.clear();
}
