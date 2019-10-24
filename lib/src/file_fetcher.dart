part of 'cache_manager.dart';
typedef Future<FileFetcherResponse> FileFetcher(String url,
    {Map<String, String> headers});

abstract class FileFetcherResponse {
  get statusCode;

  Uint8List get bodyBytes => null;

  bool hasHeader(String name);
  String header(String name);
}

class HttpFileFetcherResponse implements FileFetcherResponse {
  http.Response _response;

  HttpFileFetcherResponse(this._response);

  @override
  bool hasHeader(String name) {
    return _response.headers.containsKey(name);
  }

  @override
  String header(String name) {
    return _response.headers[name];
  }

  @override
  Uint8List get bodyBytes => _response.bodyBytes;

  @override
  get statusCode => _response.statusCode;
}
