import 'package:flutter/material.dart';

/// Crisp vector flags (no emoji dependency), matching the website's SVGs.
/// Supports fr, nl, de, es; anything else falls back to a neutral globe.
class FlagIcon extends StatelessWidget {
  final String code;
  final double width;
  final double radius;

  const FlagIcon({
    super.key,
    required this.code,
    this.width = 20,
    this.radius = 3,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    final stripes = _stripesFor(code.toLowerCase());
    if (stripes == null) {
      return Icon(Icons.language_rounded, size: height, color: Colors.white70);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Flex(
          direction: stripes.vertical ? Axis.horizontal : Axis.vertical,
          // A childless ColoredBox collapses to zero on the cross axis unless
          // the Flex stretches it.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (color, flex) in stripes.bands)
              Expanded(
                flex: flex,
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }

  static _Stripes? _stripesFor(String code) => switch (code) {
    'fr' => const _Stripes(vertical: true, bands: [
        (Color(0xFF0055A4), 1),
        (Color(0xFFFFFFFF), 1),
        (Color(0xFFEF4135), 1),
      ]),
    'nl' => const _Stripes(vertical: false, bands: [
        (Color(0xFFAE1C28), 1),
        (Color(0xFFFFFFFF), 1),
        (Color(0xFF21468B), 1),
      ]),
    'de' => const _Stripes(vertical: false, bands: [
        (Color(0xFF000000), 1),
        (Color(0xFFDD0000), 1),
        (Color(0xFFFFCE00), 1),
      ]),
    'es' => const _Stripes(vertical: false, bands: [
        (Color(0xFFAA151B), 1),
        (Color(0xFFF1BF00), 2),
        (Color(0xFFAA151B), 1),
      ]),
    _ => null,
  };
}

class _Stripes {
  final bool vertical;
  final List<(Color, int)> bands;
  const _Stripes({required this.vertical, required this.bands});
}
