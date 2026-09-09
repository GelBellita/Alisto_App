import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders a user's profile photo from the base64 string stored on
/// users/{uid}.photoBase64, falling back to a person icon.
///
/// Decoded bytes are cached in memory so scrolling doesn't re-decode the
/// same image on every rebuild.
class UserAvatar extends StatelessWidget {
  final String? base64Image;
  final double size;
  final Color backgroundColor;

  const UserAvatar({
    super.key,
    required this.base64Image,
    this.size = 46,
    this.backgroundColor = AppColors.surface,
  });

  static final Map<String, Uint8List> _cache = {};

  static Uint8List? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cached = _cache[raw];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(raw);
      // Keep the cache tiny — one or two users per session at most.
      if (_cache.length > 4) _cache.clear();
      _cache[raw] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(base64Image);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(
              Icons.person_rounded,
              size: size * 0.56,
              color: AppColors.textSecondary,
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_rounded,
                size: size * 0.56,
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}
