import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Loads and caches decoded GPU textures for vehicles and pedestrian sprites.
class UrbanSpriteCache {
  final Map<String, ui.Image> _cache = {};
  final Set<String> _pending = {};
  final Set<String> _failed = {};

  /// Returns the cached image for [assetPath], or null if pending/error.
  ui.Image? get(String assetPath) => _cache[assetPath];

  /// Asynchronously loads and decodes [assetPath] if not already cached.
  Future<void> warmUp(String assetPath, {void Function()? onLoaded}) async {
    if (_cache.containsKey(assetPath) ||
        _pending.contains(assetPath) ||
        _failed.contains(assetPath)) {
      return;
    }

    _pending.add(assetPath);
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cache[assetPath] = frame.image;
      _pending.remove(assetPath);
      onLoaded?.call();
    } catch (_) {
      _pending.remove(assetPath);
      _failed.add(assetPath);
    }
  }

  /// Disposes all cached GPU textures.
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _pending.clear();
    _failed.clear();
  }
}
