# Cached network image
A flutter library to show images from the internet and keep them in the cache directory.

## Notice

This repo was forked from [renefloor/flutter_cached_network_image](https://github.com/renefloor/flutter_cached_network_image).

## How to use

Add dependency in pubspec:

```yaml
dependencies:
  cached_network_image:
    git: 
      url: https://github.com/yrom/flutter_cached_network_image.git
      ref: feature/lru-disk-cache-store
```

The CachedNetworkImage can be used directly or through the ImageProvider.

```dart
CachedNetworkImage(
        imageUrl: "http://via.placeholder.com/350x150",
        placeholder: (context, url) => CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.error),
     ),
 ```


````dart
Image(image: CachedNetworkImageProvider(url))
````

When you want to have both the placeholder functionality and want to get the imageprovider to use in another widget you can provide an imageBuilder:
```dart
CachedNetworkImage(
  imageUrl: "http://via.placeholder.com/200x150",
  imageBuilder: (context, imageProvider) => Container(
    decoration: BoxDecoration(
      image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Colors.red, BlendMode.colorBurn)),
    ),
  ),
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
),
```

And you can define `CacheManager` on your own :

```dart

CacheManager defaultCacheManager = DefaultCacheManager(_getImagePath());
Future<String> _getImagePath() async {
  Directory dir = await getTemporaryDirectory();
  return p.join(dir.path, 'example');
}

CachedNetworkImage(
  placeholder: (context, url) => CircularProgressIndicator(),
  imageUrl: 'http://via.placeholder.com/200x150',
  cacheManager: defaultCacheManager,
)
```
