import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Loads and caches decoded [ui.Image] objects for building sprites.
///
/// Images are decoded once on first request and kept in memory for the
/// lifetime of the renderer. Call [dispose] when the renderer is torn down.
class BuildingSpriteCache {
  final Map<String, ui.Image> _cache = {};
  final Set<String> _pending = {};
  final Set<String> _failed = {};

  /// Returns a cached image for [assetPath], or null while loading / on error.
  ///
  /// Triggers an async load the first time an [assetPath] is requested.
  ui.Image? get(String assetPath) => _cache[assetPath];

  /// Begins loading [assetPath] if not already loaded or in-flight.
  ///
  /// [onLoaded] is called (from the async context) when the image is ready,
  /// so callers can schedule a repaint.
  Future<void> warmUp(String assetPath, {void Function()? onLoaded}) async {
    if (_cache.containsKey(assetPath) || _pending.contains(assetPath) || _failed.contains(assetPath)) {
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

  /// Frees all cached GPU textures.
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _pending.clear();
    _failed.clear();
  }
}
