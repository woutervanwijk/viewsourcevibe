import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/logo_service.dart';

/// Cached logo for a service/tracker, by [domain] or by a name [label];
/// shows [fallback] while loading or when no logo is available.
class ServiceLogo extends StatelessWidget {
  final String? domain;
  final String? label;
  final IconData fallback;
  final Color? color;
  final double size;

  const ServiceLogo({
    super.key,
    this.domain,
    this.label,
    required this.fallback,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = domain ?? (label == null ? null : logoDomainFor(label!));
    final icon = Icon(fallback, size: size * 0.8, color: color);
    if (resolved == null) return SizedBox.square(dimension: size, child: icon);

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: FutureBuilder(
          future: LogoService.load(resolved),
          initialData: LogoService.cached(resolved),
          builder: (_, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) return icon;
            return Image.memory(bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => icon);
          },
        ),
      ),
    );
  }
}
