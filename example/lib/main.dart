import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
void main() => runApp(MyApp());
var defaultCacheManager = DefaultCacheManager(_getImagePath());
Future<String> _getImagePath() async {
  Directory dir = await getTemporaryDirectory();
  return p.join(dir.path, 'example');
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CachedNetworkImage Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage(),
      );
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('CachedNetworkImage')),
        body: _testContent(),
      );

  _testContent() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _sizedContainer(
              Image(
                image: CachedNetworkImageProvider(
                  'http://via.placeholder.com/350x150',
                  cacheManager: defaultCacheManager,
                ),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                placeholder: (context, url) => CircularProgressIndicator(),
                imageUrl: 'http://via.placeholder.com/200x150',
                cacheManager: defaultCacheManager,
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://via.placeholder.com/300x150',
                cacheManager: defaultCacheManager,
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.red,
                        BlendMode.colorBurn,
                      ),
                    ),
                  ),
                ),
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                cacheManager: defaultCacheManager,
                imageUrl: 'http://notAvalid.uri',
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'not a uri at all',
                cacheManager: defaultCacheManager,
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://via.placeholder.com/350x200',
                cacheManager: defaultCacheManager,
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fadeOutDuration: const Duration(seconds: 1),
                fadeInDuration: const Duration(seconds: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _gridView() {
    return GridView.builder(
      itemCount: 250,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemBuilder: (BuildContext context, int index) => CachedNetworkImage(
        imageUrl: 'http://via.placeholder.com/'
            '${(index + 1)}',
        cacheManager: defaultCacheManager,
        placeholder: _loader,
        errorWidget: _error,
      ),
    );
  }

  Widget _loader(BuildContext context, String url) => Center(
        child: CircularProgressIndicator(),
      );

  Widget _error(BuildContext context, String url, Object error) {
    print(error);
    return Center(child: const Icon(Icons.error));
  }

  Widget _sizedContainer(Widget child) => SizedBox(
        width: 300.0,
        height: 150.0,
        child: Center(child: child),
      );
}
