import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'cached_image_manager.dart';

/// Decodes the given [BinaryResource] object as an image, associating it with the given
/// scale.
class ScaledImage extends ImageProvider<_ScaledImageKey> {
  /// Creates an object that decodes a [File] as an image.
  ///
  /// The arguments must not be null.
  const ScaledImage(this.resource,
      {this.scale = 1.0, this.targetHeight, this.targetWidth})
      : assert(resource != null),
        assert(scale != null);

  /// The resource to decode into an image.
  final BinaryResource resource;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The targetHeight to which the image is scaled after decoding and before
  /// generating the Image object
  final int targetHeight;

  /// The targetWidth to which the image is scaled after decoding and before
  /// generating the Image object
  final int targetWidth;

  @override
  Future<_ScaledImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ScaledImageKey>(_ScaledImageKey(
      resource.id,
      scale: scale,
      targetHeight: targetHeight,
      targetWidth: targetWidth,
    ));
  }

  @override
  ImageStreamCompleter load(_ScaledImageKey key,
      [Future<Codec> decode(Uint8List bytes,
          {int cacheWidth, int cacheHeight})]) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('BinaryResource: ${resource.toString()}');
      },
    );
  }

  Future<Codec> _loadAsync(_ScaledImageKey key, Function decode) async {
    assert(key.resourceId == this.resource.id);

    final Uint8List bytes = await this.resource.readAsBytes();
    if (bytes.lengthInBytes == 0) {
      throw Exception("Can not instantiate image codec for zero length bytes");
    }
    if (decode != null) {
      return decode(bytes, cacheWidth: targetWidth, cacheHeight: targetHeight);
    }
    return instantiateImageCodec(bytes,
        targetWidth: targetWidth, targetHeight: targetHeight);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ScaledImage typedOther = other;
    return resource == typedOther.resource &&
        scale == typedOther.scale &&
        targetWidth == typedOther.targetWidth &&
        targetHeight == typedOther.targetHeight;
  }

  @override
  int get hashCode => hashValues(resource, scale);

  @override
  String toString() => '$runtimeType("$resource", scale: $scale, '
      'targetHeight: $targetHeight, targetWidth: $targetWidth)';
}

class _ScaledImageKey {
  String resourceId;
  double scale;
  int targetWidth;
  int targetHeight;

  _ScaledImageKey(
    this.resourceId, {
    this.scale,
    this.targetWidth,
    this.targetHeight,
  });

  @override
  String toString() {
    return '_ScaledImageKey: $resourceId';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ScaledImageKey &&
            runtimeType == other.runtimeType &&
            resourceId == other.resourceId &&
            scale == other.scale &&
            targetWidth == other.targetWidth &&
            targetHeight == other.targetHeight;
  }

  @override
  int get hashCode => hashValues(resourceId, scale, targetWidth, targetHeight);
}
