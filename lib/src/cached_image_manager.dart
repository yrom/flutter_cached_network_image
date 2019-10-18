import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as fcm;

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
  Future<BinaryResource> getImageResource(String url,
      {Map<String, String> headers});
}

/// Binary resource for decoding image.
///
/// See also:
///  * [ScaledImage]
///  * [CachedNetworkImageProvider]
abstract class BinaryResource {
  factory BinaryResource.file(File file) => FileResource(file);
  factory BinaryResource.memory(ByteData buff) => ByteDataResource(buff);

  Uint8List readAsBytesSync();
  Future<Uint8List> readAsBytes();
}

class CachedImage {
  final String originalUrl;
  final DateTime validTill;
  final BinaryResource resource;

  CachedImage(this.originalUrl, this.validTill, this.resource);
  factory CachedImage.file(String originalUrl, File file,
      {DateTime validTill}) {
    return CachedImage(originalUrl, validTill, BinaryResource.file(file));
  }
}

/// Default [CacheManager] implementation by package 'flutter_cache_manager'.
/// See https://pub.dev/packages/flutter_cache_manager for more details.
class DefaultCacheManager implements CacheManager {
  static DefaultCacheManager _instance;

  factory DefaultCacheManager() {
    if (_instance == null) {
      _instance = DefaultCacheManager._(fcm.DefaultCacheManager());
    }
    return _instance;
  }
  final fcm.BaseCacheManager manager;

  DefaultCacheManager._(this.manager);

  @override
  Stream<CachedImage> getImage(String imageUrl, {Map<String, String> headers}) {
    return manager.getFile(imageUrl, headers: headers).map(_convert);
  }

  @override
  CachedImage getImageFromMemory(String imageUrl) {
    return _convert(manager.getFileFromMemory(imageUrl));
  }

  CachedImage _convert(fcm.FileInfo info) {
    if (info == null) return null;
    return CachedImage.file(
      info.originalUrl,
      info.file,
      validTill: info.validTill,
    );
  }

  @override
  Future<BinaryResource> getImageResource(String url,
      {Map<String, String> headers}) {
    return manager
        .getSingleFile(url, headers: headers)
        .then((file) => FileResource(file));
  }
}

class ByteDataResource implements BinaryResource {
  final ByteData data;
  const ByteDataResource(this.data) : assert(data != null);

  @override
  Uint8List readAsBytesSync() {
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<Uint8List> readAsBytes() {
    return Future.sync(readAsBytesSync);
  }

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final ByteDataResource typedOther = other;
    return data == typedOther.data;
  }

  @override
  String toString() {
    return "bytebuff:$data";
  }
}

class FileResource implements BinaryResource {
  final File file;
  const FileResource(this.file) : assert(file != null);

  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() {
    return file.readAsBytes();
  }

  @override
  int get hashCode => file.hashCode;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final FileResource typedOther = other;
    return file.path == typedOther.file.path;
  }

  @override
  String toString() {
    return "file:${file.path}";
  }
}
