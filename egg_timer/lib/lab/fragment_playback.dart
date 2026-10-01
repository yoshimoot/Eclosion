import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Inspection clock: late frames extend playback instead of skipping material
/// states. This is deliberately not the wall-clock timer of the final product.
class FragmentPlayback extends ChangeNotifier {
  FragmentPlayback({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  static const duration = Duration(seconds: 6);
  // At least 30 displayed steps per simulated second, even after a stall.
  static const maxFrameTime = Duration(microseconds: 33334);
  late final Ticker _ticker;
  Duration? _previous;
  double _value = 0;
  bool _slow = false;
  double get value => _value;
  bool get isAnimating => _ticker.isActive;

  set slow(bool value) {
    _slow = value;
  }

  // Explicit user seeking is the only operation allowed to jump.
  set value(double value) {
    stop();
    _value = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void forward({double? from}) {
    if (from != null) {
      stop();
      _value = from.clamp(0.0, 1.0);
    }
    if (!_ticker.isActive && _value < 1) {
      _previous = null;
      _ticker.start();
    }
    notifyListeners();
  }

  void stop() {
    _ticker.stop();
    _previous = null;
    notifyListeners();
  }

  void reset() => value = 0;

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (previous == null) return;
    final delta = (elapsed - previous).inMicroseconds.clamp(
      0,
      maxFrameTime.inMicroseconds,
    );
    // No accumulated debt: recovery cannot replay a delayed wall-clock jump.
    _value = (_value + delta / duration.inMicroseconds / (_slow ? 4 : 1)).clamp(
      0.0,
      1.0,
    );
    if (_value == 1) {
      _ticker.stop();
      _previous = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
