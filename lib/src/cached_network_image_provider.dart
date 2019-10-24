import 'dart:async' show Future;
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cache_manager.dart';
import 'cached_image_manager.dart';

typedef void ErrorListener();

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  /// Creates an ImageProvider which loads an image from the [url], using the [scale].
  /// When the image fails to load [errorListener] is called.
  const CachedNetworkImageProvider(this.url,
      {this.scale: 1.0,
      this.errorListener,
      this.headers,
      this.cacheManager,
      this.targetWidth,
      this.targetHeight})
      : assert(url != null),
        assert(scale != null);

  final CacheManager cacheManager;

  /// Web url of the image to load
  final String url;

  /// Scale of the image
  final double scale;

  /// Target image width, to which the image shall be scaled after decoding
  final int targetWidth;

  /// Target image height, to which the image shall be scaled after decoding
  final int targetHeight;

  /// Listener to be called when images fails to load.
  final ErrorListener errorListener;

  // Set headers for the image provider, for example for authentication
  final Map<String, String> headers;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(CachedNetworkImageProvider key) async {
    var mngr = cacheManager ?? DefaultCacheManager();
    var resource = await mngr.getImageResource(url, headers: headers);
    if (resource == null) {
      if (errorListener != null) errorListener();
      return Future<ui.Codec>.error("Couldn't download or retrieve file.");
    }
    return await _loadAsyncFromResource(key, resource);
  }

  Future<ui.Codec> _loadAsyncFromResource(
      CachedNetworkImageProvider key, BinaryResource resource) async {
    assert(key == this);

    final Uint8List bytes = await resource.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      if (errorListener != null) errorListener();
      throw Exception("BinaryResource was empty");
    }

    return await ui.instantiateImageCodec(bytes,
        targetWidth: targetWidth, targetHeight: targetHeight);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final CachedNetworkImageProvider typedOther = other;
    return url == typedOther.url &&
        scale == typedOther.scale &&
        targetWidth == typedOther.targetWidth &&
        targetHeight == typedOther.targetHeight;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
