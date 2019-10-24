import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'crc32.dart';

/// Manager for getting [CachedImage].
abstract class CacheManager {
  /// Try to get the image from memory directly.
  CachedImage getImageFromMemory(String imageUrl);

  /// Get the image from the cache.
  /// Download form [url] if the cache was missing or expired. And the [headers]
  /// can be used for example for authentication.
  ///
  /// The files are returned as stream. First the cached file if available, when the
  /// cached file is expired the newly downloaded file is returned afterwards.
  Stream<CachedImage> getImage(String url, {Map<String, String> headers});

  /// Try to get the cached image file. Download form [url] when missing.
  Future<BinaryResource> getImageResource(String url, {Map<String, String> headers});
}

/// Binary resource for decoding image.
///
/// See also:
///  * [ScaledImage]
///  * [CachedNetworkImageProvider]
abstract class BinaryResource {
  factory BinaryResource.file(String id, File file) = FileResource;

  factory BinaryResource.memory(String id, ByteData buff) = ByteDataResource;

  /// resource unique id
  final String id;

  Uint8List readAsBytesSync();

  Future<Uint8List> readAsBytes();

  /// bytes length
  int get length;
}

class CachedImage {
  final String originalUrl;
  final BinaryResource resource;

  CachedImage(this.originalUrl, this.resource);
}

class ByteDataResource implements BinaryResource {
  final ByteData data;

  @override
  final String id;

  const ByteDataResource(this.id, this.data)
      : assert(id != null),
        assert(data != null);

  @override
  Uint8List readAsBytesSync() {
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<Uint8List> readAsBytes() {
    return Future.sync(readAsBytesSync);
  }

  @override
  int get length => data.lengthInBytes;

  @override
  int get hashCode => getCrc32(readAsBytesSync());

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final ByteDataResource typedOther = other;
    if (data == typedOther.data || id == typedOther.id) return true;
    if (data.lengthInBytes == typedOther.data.lengthInBytes &&
        data.offsetInBytes == typedOther.data.offsetInBytes) {
      return hashCode == typedOther.hashCode;
    }
    return false;
  }

  @override
  String toString() {
    return "bytebuff:$data";
  }
}

class FileResource implements BinaryResource {
  final File file;

  @override
  final String id;

  const FileResource(this.id, this.file)
      : assert(id != null),
        assert(file != null);

  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() {
    return file.readAsBytes();
  }

  @override
  int get length => file.lengthSync();

  @override
  int get hashCode => file.hashCode;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final FileResource typedOther = other;
    return id == typedOther.id || file.path == typedOther.file.path;
  }

  @override
  String toString() {
    return "file:${file.path}";
  }
}
