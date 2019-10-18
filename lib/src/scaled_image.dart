import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'cached_image_manager.dart';

/// Decodes the given [BinaryResource] object as an image, associating it with the given
/// scale. 
class ScaledImage extends ImageProvider<ScaledImage> {
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
  Future<ScaledImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ScaledImage>(this);
  }

  @override
  ImageStreamCompleter load(ScaledImage key) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('BinaryResource: ${resource.toString()}');
      },
    );
  }

  Future<Codec> _loadAsync(ScaledImage key) async {
    assert(key == this);

    final Uint8List bytes = await key.resource.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;

    return await instantiateImageCodec(bytes,
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