import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

void main() {
  test("bytedata binaryresource", () {
    var bytes = Uint8List.fromList([0, 0, 1, 0, 1, 2, 3]);
    var resource1 = BinaryResource.memory("test1", bytes.buffer.asByteData());
    var resource2 = BinaryResource.memory("test1", bytes.buffer.asByteData());
    expect(resource1.length, bytes.lengthInBytes);
    expect(resource2.length, bytes.lengthInBytes);
    expect(resource1 == resource2, true);
  });

  test("file binaryresource", () {
    var file = MockFile("/test");
    when(file.lengthSync()).thenReturn(10);
    var resource1 = BinaryResource.file("test", file);
    var resource2 = BinaryResource.file("test", file);
    expect(resource1.length, 10);
    expect(resource1 == resource2, true);
  });
}

class MockFile extends Mock implements File {
  MockFile(this.path);

  @override
  final String path;
}
