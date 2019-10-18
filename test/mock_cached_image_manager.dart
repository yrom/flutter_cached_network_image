import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mockito/mockito.dart';
import 'package:cached_network_image/src/cached_image_manager.dart';

class MockCacheManager extends Mock implements CacheManager {}

class MockFile extends Mock implements File {}

class MockBinaryResource extends Mock implements BinaryResource {}

BinaryResource mockFile(Uint8List bytes()) {
  var f = MockBinaryResource();
  when(f.readAsBytes()).thenAnswer((_) => Future.sync(bytes));
  when(f.readAsBytesSync()).thenReturn(bytes());
  return f;
}
