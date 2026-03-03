import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A small helper that shows a user's profile photo when available,
/// otherwise falls back to a letter/initials inside a [CircleAvatar].
///
/// If [useCachedNetworkImage] is true the widget will render a
/// `CachedNetworkImage` inside a clip to provide a placeholder and error
/// widget during loading and failures (useful for larger avatar displays).
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? initials;
  final double? radius;
  final Color? backgroundColor;
  final bool useCachedNetworkImage;
  final BoxFit imageFit;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.initials,
    this.radius,
    this.backgroundColor,
    /// Default to using the widget-based cached image which provides a
    /// placeholder and graceful error fallback. This prevents an empty
    /// CircleAvatar when the image fails to load (e.g. invalid URL).
    this.useCachedNetworkImage = true,
    this.imageFit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Accept any non-empty photoUrl and let the image provider handle
    // invalid/unsupported schemes (it will render the errorWidget fallback).
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    if (hasPhoto && useCachedNetworkImage) {
      final size = (radius ?? 20) * 2;
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl!,
            width: size,
            height: size,
            fit: imageFit,
            placeholder: (ctx, url) => Container(
              color: backgroundColor ?? Theme.of(context).primaryColor.withAlpha((0.12 * 255).toInt()),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (ctx, url, err) => Container(
              color: backgroundColor ?? Theme.of(context).primaryColor.withAlpha((0.12 * 255).toInt()),
              child: Center(
                child: Text(
                  initials ?? '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: (radius != null) ? (radius! * 0.5) : 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (hasPhoto) {
      // When a photo url exists (but the widget-based cached image was disabled),
      // fall back to an Image.network with an errorBuilder to ensure a graceful
      // fallback instead of an empty avatar.
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: (radius ?? 20) * 2,
            height: (radius ?? 20) * 2,
            fit: imageFit,
            errorBuilder: (ctx, error, stack) => Center(
              child: Text(
                initials ?? '?',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: (radius != null) ? (radius! * 0.5) : 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withAlpha((0.12 * 255).toInt()),
      child: Text(
        (initials != null && initials!.isNotEmpty) ? initials! : '?',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: (radius != null) ? (radius! * 0.5) : 16,
        ),
      ),
    );
  }
}
