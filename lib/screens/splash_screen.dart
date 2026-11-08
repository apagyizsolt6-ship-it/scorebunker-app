import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animált indítóképernyő: a focilabda leesik, pattog és forog, majd
/// felúszik az APISCORES felirat. Koppintásra átugorható.
/// A mögötte lévő app közben már betöltődik.
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;
  bool _hiding = false;
  bool _gone = false;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _hold = Timer(const Duration(milliseconds: 250), _hide);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Ha a telefonon ki van kapcsolva az animáció, az indítókép kimarad.
    if (MediaQuery.of(context).disableAnimations) {
      _gone = true;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _hide() {
    if (!mounted || _hiding) return;
    setState(() => _hiding = true);
  }

  double _t(double a, double b, Curve curve) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_gone)
          IgnorePointer(
            ignoring: _hiding,
            child: AnimatedOpacity(
              opacity: _hiding ? 0 : 1,
              duration: const Duration(milliseconds: 450),
              onEnd: () {
                if (_hiding && mounted) setState(() => _gone = true);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hide,
                child: _splash(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _splash() {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final drop = _t(0.0, 0.55, Curves.bounceOut);
        final spin = _t(0.0, 0.75, Curves.easeOutCubic);
        final text = _t(0.50, 0.85, Curves.easeOut);
        final sub = _t(0.65, 1.0, Curves.easeOut);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A73E8), Color(0xFF274BA8)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, -260 * (1 - drop)),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * drop,
                    child: CustomPaint(
                      size: const Size(150, 150),
                      painter: _BallPainter(rotation: spin * math.pi * 3),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: text,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - text)),
                    child: const Text(
                      'APISCORES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: sub,
                  child: const Text(
                    'élő eredmények • tabellák • trendek',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ugyanaz a focilabda, mint az app ikonján.
class _BallPainter extends CustomPainter {
  final double rotation;
  const _BallPainter({required this.rotation});

  static const Color _ink = Color(0xFF141828);

  List<Offset> _poly(Offset c, double r, double rotDeg) => [
        for (var i = 0; i < 5; i++)
          Offset(
            c.dx + r * math.cos((rotDeg + i * 72) * math.pi / 180),
            c.dy + r * math.sin((rotDeg + i * 72) * math.pi / 180),
          ),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);

    final fill = Paint()..color = Colors.white;
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset.zero, r, fill);
    canvas.drawCircle(Offset.zero, r, line);

    final inner = _poly(Offset.zero, r * 0.38, -90);
    final outer = _poly(Offset.zero, r * 0.98, -90);
    canvas.drawPath(Path()..addPolygon(inner, true), ink);
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(inner[i], outer[i], line);
    }

    for (var i = 0; i < 5; i++) {
      final a = (-90 + i * 72 + 36) * math.pi / 180;
      final c = Offset(r * 0.80 * math.cos(a), r * 0.80 * math.sin(a));
      final pts = _poly(c, r * 0.17, a * 180 / math.pi + 180);
      canvas.drawPath(Path()..addPolygon(pts, true), ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BallPainter old) => old.rotation != rotation;
}
