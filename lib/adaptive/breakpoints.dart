import 'package:flutter/material.dart';

/// Form factors for a single Pokke binary (phone / tablet / desktop / TV).
enum PokkeFormFactor { phone, tablet, desktop, tv }

class Breakpoints {
  /// Width heuristics + TV detection via platform / large short side.
  static PokkeFormFactor of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final width = size.width;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    // Android TV / Google TV often report large screens with no notch and
    // navigation mode that looks "lean-back". We also treat ultra-wide + large
    // shortest side as TV when height is limited relative to width.
    final isTvLike = (width >= 900 && shortest >= 500 && viewPadding.top < 8) &&
        (size.height / size.width < 0.72);

    if (isTvLike || width >= 1280 && shortest >= 720) {
      // Prefer TV layout for lean-back if aspect is landscape-dominant
      if (size.aspectRatio >= 1.5 && shortest >= 600) {
        return PokkeFormFactor.tv;
      }
    }

    if (width >= 1100) return PokkeFormFactor.desktop;
    if (width >= 700 || shortest >= 600) return PokkeFormFactor.tablet;
    return PokkeFormFactor.phone;
  }

  static bool isCompact(BuildContext context) =>
      of(context) == PokkeFormFactor.phone;

  static bool useSideNav(BuildContext context) {
    final f = of(context);
    return f == PokkeFormFactor.desktop ||
        f == PokkeFormFactor.tv ||
        f == PokkeFormFactor.tablet;
  }
}
