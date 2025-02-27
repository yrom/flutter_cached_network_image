import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:quiver/collection.dart';

part 'file_fetcher.dart';

/// Generate cache key of [url].
/// See [CacheEntity.key].
typedef String CacheKeyGenerator(String url);

typedef Future<void> BinaryResourcePersistence(
    File file, BinaryResource resource);

String _defaultCacheKeyGenerator(String url) {
  return url.isEmpty ? '' : sha1.convert(url.codeUnits).toString();
}

Future<FileFetcherResponse> _defaultFileFetcher(String url,
    {Map<String, String> headers}) {
  return http
      .get(url, headers: headers)
      .then((v) => HttpFileFetcherResponse(v));
}

Future<void> _defaultBinaryResourcePersistence(
    File file, BinaryResource resource) async {
  Directory dir = file.parent;
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final bytes = resource.readAsBytesSync();
  assert(bytes != null);
  await file.writeAsBytes(bytes, flush: true);
}

class DiskCacheManager extends CacheManager {
  final DiskCacheStore store;
  final RemoteResourceDownloader downloader;
  final CacheKeyGenerator keyGenerator;

  DiskCacheManager(
    this.store, {
    FileFetcher fileFetcher = _defaultFileFetcher,
    this.keyGenerator = _defaultCacheKeyGenerator,
  })  : assert(store != null),
        assert(fileFetcher != null),
        assert(keyGenerator != null),
        this.downloader = RemoteResourceDownloader(store, fileFetcher);

  @override
  Stream<CachedImage> getImage(String url, {Map<String, String> headers}) {
    final controller = StreamController<BinaryResource>();

    controller.onListen = () async {
      if (url == null || url.isEmpty) {
        controller.addError(ArgumentError("Invalid url!"));
        await controller.close();
        return;
      }
      final key = _keyOf(url);

      BinaryResource cache;
      try {
        cache = await store.get(key);
      } catch (e) {
        // fallthrough
        cache = null;
      }
      // TODO: validate cache age
      if (cache != null) {
        if (controller.hasListener) controller.add(cache);
      } else {
        try {
          final remote = await downloader.download(key, url, headers: headers);
          if (remote.length > 0) {
            if (controller.hasListener) {
              controller.add(remote);
            }
          } else {
            throw Exception("Invalid length of resource: $remote");
          }
        } catch (e, stack) {
          if (controller.hasListener) {
            controller.addError(e, stack);
          } else {
            FlutterError.reportError(FlutterErrorDetails(
                exception: e,
                stack: StackTrace.fromString(stack
                    .toString()
                    .trimRight()
                    .split('\n')
                    .reversed
                    .skipWhile((line) =>
                        !line.contains("package:cached_network_image"))
                    .toList(growable: false)
                    .reversed
                    .join('\n')),
                silent: true,
                library: 'cache manager library',
                context: ErrorDescription('while loading image'),
                informationCollector: () =>
                    [StringProperty("Image url", url)]));
          }
        }
      }
      await controller.close();
    };

    return controller.stream
        .map<CachedImage>((cache) => CachedImage(url, cache));
  }

  @override
  CachedImage getImageFromMemory(String imageUrl) {
    final key = _keyOf(imageUrl);
    final fromMemory = store.getFromMemory(key);
    if (fromMemory != null) return CachedImage(imageUrl, fromMemory);
    return null;
  }

  @override
  Future<BinaryResource> getImageResource(String url,
      {Map<String, String> headers}) {
    final completer = Completer<BinaryResource>.sync();
    getImage(url, headers: headers).listen(
      (image) => completer.complete(image.resource),
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  final _keyCache = LruMap<String, String>();

  String _keyOf(String url) {
    return _keyCache.putIfAbsent(url, () => keyGenerator(url));
  }
}

class DiskCacheStore {
  static const _buckets = 100;
  static const _ext = '.bc';
  static const _dirname = "fimg.v1";
  static const _defaultCacheSize = 100 * 1024 * 1024;
  static const _minCacheSize = 5 * 1024 * 1024;
  static const _defaultMaxAge = Duration(days: 5);
  static const _statsInterval = Duration(minutes: 5);
  final memCache = LruMap<String, BinaryResource>(maximumSize: 24);
  final _pending = Map<String, Completer<BinaryResource>>();
  final Future<Directory> baseDir;
  final DiskCacheStats stats = DiskCacheStats();

  final int _cacheSizeLimit;

  final Duration _maxAge;
  final BinaryResourcePersistence _persistence;

  DiskCacheStore(
    Future<String> basePath, {
    int cacheSizeLimit = _defaultCacheSize,
    Duration maxAge = _defaultMaxAge,
    BinaryResourcePersistence persistence = _defaultBinaryResourcePersistence,
  })  : assert(basePath != null),
        assert(persistence != null),
        baseDir = basePath.then((v) => Directory(path.join(v, _dirname))),
        _persistence = persistence,
        _cacheSizeLimit = cacheSizeLimit ?? _minCacheSize,
        _maxAge = maxAge ?? _defaultMaxAge {
    _maybeUpdateCachedSize();
  }

  BinaryResource getFromMemory(String key) {
    var resource = memCache[key];
    if (resource is FileResource && resource.file.existsSync()) {
      return resource;
    }
    memCache.remove(key);
    return null;
  }

  Future<BinaryResource> get(String key) {
    var pending = _pending[key];
    if (pending != null) return pending.future;
    final completer = Completer<BinaryResource>.sync();
    _pending[key] = completer;

    _loadCache(key).then(
      (resource) {
        if (resource != null) {
          memCache[key] = resource;
          completer.complete(resource);
        } else {
          completer.complete(null);
        }
      },
      onError: completer.completeError,
    ).whenComplete(() {
      _pending.remove(key);
    });

    return completer.future;
  }

  Future<void> put(BinaryResource resource) {
    if (memCache[resource.id] == null) {
      // avoid redundant writing
      memCache[resource.id] = resource;
      return _writeCache(resource.id, resource);
    }
    return Future.value();
  }

  Future<void> _writeCache(String key, BinaryResource resource) async {
    if (stats.isInitialized) {
      stats.increment(resource.length, 1);
    } else if (_updatingFuture != null) {
      unawaited(
          _updatingFuture.then((_) => stats.increment(resource.length, 1)));
    }
    File file = File(await getSavePath(key));
    try {
      if (resource.length <= 0) {
        // remove file if invalid
        try {
          if (file.existsSync()) await file.delete();
        } on FileSystemException catch (_) {
          // ignored
        }
        memCache.remove(key);
      } else {
        await _persistence(file, resource);
        // rewrite memCache after saving
        memCache[key] = BinaryResource.file(key, file);
        _maybeEvictFilesOverSize();
      }
    } on FileSystemException catch (e, stack) {
      // ENOSPC
      if (e.osError?.errorCode == 28) {
        unawaited(_trimExpiredEntries());
      } else {
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'cache manager library',
          context: ErrorDescription('while writing file'),
          informationCollector: () => [StringProperty("File path", file.path)],
          silent: !kDebugMode,
        ));
      }
    }
  }

  Future<BinaryResource> _loadCache(String key) async {
    BinaryResource resource;
    File file = File(await getSavePath(key));
    if (file.existsSync()) {
      // promote this file.
      await _touch(file);
      resource = BinaryResource.file(key, file);
    }
    _maybeEvictFilesOverSize();
    return resource;
  }

  Future _touch(File file) {
    return file.setLastModified(DateTime.now());
  }

  Future<String> getSavePath(String key) async {
    return path.join(await getSubdirs(key), getFileName(key));
  }

  String getFileName(String key) => "$key$_ext";

  String cacheKeyFromFile(File file) =>
      path.basenameWithoutExtension(file.path);

  Future<String> getSubdirs(String key) async {
    Directory folder = await baseDir;

    int bucekt = key.hashCode.toUnsigned(8) % _buckets;
    return path.join(folder.path, bucekt.toString());
  }

  Future<List<BinaryResource>> getAllEntities() async {
    var files = await listFiles(await baseDir);
    if (files.isEmpty) return const [];
    return files
        .where((f) => path.extension(f.path) == _ext)
        .map((f) => BinaryResource.file(cacheKeyFromFile(f), f))
        .toList(growable: false);
  }

  DateTime _cachedSizeUpdateTime;
  Future _updatingFuture;
  Future _purgeFuture;

  void _maybeUpdateCachedSize() {
    if (!stats.isInitialized ||
        _cachedSizeUpdateTime == null ||
        DateTime.now().difference(_cachedSizeUpdateTime) > _statsInterval) {
      if (_updatingFuture == null) {
        _updatingFuture = _updateFileCacheSize();
        _updatingFuture.whenComplete(() {
          assert(() {
            print(
                "Cached file stats: size ${stats.size}, count ${stats.count}");
            return true;
          }());
          _updatingFuture = null;
          _cachedSizeUpdateTime = DateTime.now();
        });
      }
    }
  }

  Future _updateFileCacheSize() async {
    var files = await listFilesAndMap(
        await baseDir, (f) => f.length().catchError((_) => 0));
    var count = files.length;
    var size =
        count == 0 ? 0 : files.map((e) => e.value).reduce((a, b) => a + b);
    if (stats.size != size || stats.count != count) {
      stats.set(size, count);
    }
  }

  void _maybeEvictFilesOverSize() {
    if (stats.isInitialized && stats.size < _cacheSizeLimit) {
      return;
    }
    Function() tryPurge = () {
      if (stats.size > _cacheSizeLimit && _purgeFuture == null) {
        _purgeFuture = _trimBySize();
        _purgeFuture.whenComplete(() {
          _purgeFuture = null;
        });
      }
    };
    if (_updatingFuture == null) {
      // force update stats if exceed size limit
      stats.reset();
      _maybeUpdateCachedSize();
    }
    if (_updatingFuture != null) {
      _updatingFuture.then((_) => tryPurge());
    } else {
      // should not happen.
      tryPurge();
    }
  }

  Future _trimBySize() {
    return _purge(bySize: true, byTime: false);
  }

  // ignore: unused_element
  Future _trimExpiredEntries() {
    return _purge(bySize: false, byTime: true);
  }

  Future _purge({bySize = true, byTime = false}) async {
    List<MapEntry<File, DateTime>> sortedList = await _getSortedEntries();
    if (sortedList.isEmpty) return;
    int freeSize = -1;
    int expiredIndex = -1;
    if (bySize) {
      int desiredSize = _cacheSizeLimit * 8 ~/ 10;
      freeSize = stats.size - desiredSize;
    }
    if (byTime) {
      DateTime expiredTime = DateTime.now().subtract(_maxAge);
      expiredIndex =
          sortedList.indexWhere((entry) => entry.value.isAfter(expiredTime));
    }

    int sumSize = 0;
    int count = 0;
    int index = 0;
    for (final file in sortedList) {
      if (bySize && sumSize > freeSize) break;
      if (byTime && index >= expiredIndex) break;
      index++;
      var f = file.key;
      assert(() {
        print("Remove cache $f");
        return true;
      }());
      var key = cacheKeyFromFile(f);
      if (key != null) {
        // difficult to run here
        memCache.remove(key);
      }
      try {
        int deleteSize = await f.length();
        await f.delete();
        count++;
        sumSize += deleteSize;
      } on FileSystemException catch (_) {
        // ignore
      }
    }
    if (count > 0) {
      stats.increment(-sumSize, -count);
      _maybeUpdateCachedSize();
    }
  }

  Future<List<MapEntry<File, DateTime>>> _getSortedEntries() async {
    var files = await listFilesAndMap(await baseDir,
        (f) => f.lastModified().catchError((_) => DateTime.now()));
    if (files.isEmpty) return const [];
    var futureTime = DateTime.now().add(const Duration(hours: 2));
    var sortedList = <MapEntry<File, DateTime>>[];
    var listToSort = <MapEntry<File, DateTime>>[];
    for (final file in files) {
      // this file was written with future timestamp
      if (file.value.isAfter(futureTime)) {
        sortedList.add(file);
      } else {
        listToSort.add(file);
      }
    }
    listToSort.sort((a, b) => a.value.compareTo(b.value));
    sortedList.addAll(listToSort);
    return sortedList;
  }
}

class DiskCacheStats {
  bool _isInitialized = false;
  int _size = -1;
  int _count = -1;

  bool get isInitialized => _isInitialized;

  int get size => _size;

  int get count => _count;

  void reset() {
    _isInitialized = false;
    _size = _count = -1;
  }

  void set(int size, int count) {
    this._size = size;
    this._count = count;
    _isInitialized = true;
  }

  void increment(int size, int count) {
    if (_isInitialized) {
      this._size += size;
      this._count += count;
    }
  }

  @override
  String toString() {
    return '{size: $_size, count: $_count}';
  }
}

class RemoteResourceDownloader {
  final FileFetcher fetcher;

  final Map<String, Completer<BinaryResource>> _mem = Map();

  final DiskCacheStore store;

  RemoteResourceDownloader(this.store, this.fetcher);

  Future<BinaryResource> download(String key, String url,
      {Map<String, String> headers}) {
    if (_mem.containsKey(url)) {
      return _mem[url].future;
    }

    var completer = Completer<BinaryResource>.sync();
    _mem[url] = completer;

    fetcher(url, headers: headers)
        .then((response) => _handleResponse(key, url, response))
        .then(completer.complete)
        .catchError(completer.completeError)
        .whenComplete(() => _mem.remove(url));
    return completer.future;
  }

  BinaryResource _handleResponse(
      String key, String url, FileFetcherResponse response) {
    if (response.statusCode == 200) {
      Uint8List body = response.bodyBytes;
      if (body == null) {
        throw HttpException("Null body!", uri: Uri.parse(url));
      }
      var resource = BinaryResource.memory(key, body.buffer.asByteData());
      store.put(resource);
      return resource;
    }
    throw HttpException("Invalid status: ${response.statusCode}",
        uri: Uri.parse(url));
  }
}

class DefaultCacheManager extends DiskCacheManager {
  static DiskCacheManager _instance;

  factory DefaultCacheManager([Future<String> basePath]) {
    if (_instance == null) {
      _instance = DefaultCacheManager._(basePath);
    }
    return _instance;
  }

  static Future<String> _getImageCachePath() async {
    Directory dir = await p.getTemporaryDirectory();
    return dir.path;
  }

  DefaultCacheManager._(Future<String> basePath)
      : super(
          DiskCacheStore(basePath ?? _getImageCachePath()),
        );
}

Future<List<File>> listFiles(Directory dir) {
  return dir.exists().then((exists) {
    if (exists) {
      return dir
          .list(recursive: true, followLinks: false)
          .handleError(() {}, test: (e) => e is FileSystemException)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
    }
    return const <File>[];
  });
}

Future<List<MapEntry<File, E>>> listFilesAndMap<E>(
    Directory dir, FutureOr<E> map(File file)) {
  return dir.exists().then((exists) {
    if (exists) {
      return dir
          .list(recursive: true, followLinks: false)
          .handleError(() {}, test: (e) => e is FileSystemException)
          .where((entity) => entity is File)
          .cast<File>()
          .asyncMap((file) async => MapEntry(file, await map(file)))
          .toList();
    }
    return const [];
  });
}
