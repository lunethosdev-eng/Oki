import 'package:flutter/material.dart';
import 'package:pokke/adaptive/breakpoints.dart';

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final f = Breakpoints.of(context);
    final h = switch (f) {
      PokkeFormFactor.phone => 16.0,
      PokkeFormFactor.tablet => 24.0,
      PokkeFormFactor.desktop => 32.0,
      PokkeFormFactor.tv => 40.0,
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: child,
    );
  }
}

/// Grid columns by form factor.
int gridColumns(BuildContext context) {
  return switch (Breakpoints.of(context)) {
    PokkeFormFactor.phone => 2,
    PokkeFormFactor.tablet => 3,
    PokkeFormFactor.desktop => 5,
    PokkeFormFactor.tv => 6,
  };
}
