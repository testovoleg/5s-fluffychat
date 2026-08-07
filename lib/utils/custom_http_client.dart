// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:http/http.dart' as http;
import 'package:http/retry.dart' as retry;
import 'package:matrix/matrix.dart';

import 'custom_http_client_stub.dart'
    if (dart.library.io) 'custom_http_client_native.dart';

/// Creates the HTTP client used by the Matrix SDK.
///
/// On Android this uses Cronet via [createPlatformHttpClient]; elsewhere the
/// default [http.Client] is used. Cronet is loaded only on `dart:io` platforms
/// so the web build does not pull in the JNI-based `cronet_http` package.
class CustomHttpClient {
  static http.Client createHTTPClient() =>
      retry.RetryClient(_DiagnosticHttpClient(createPlatformHttpClient()));
}

class _DiagnosticHttpClient extends http.BaseClient {
  final http.Client _inner;

  _DiagnosticHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final uri = request.url;
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      final stackTrace = StackTrace.current;
      final exception = http.ClientException(
        'Invalid absolute HTTP URL for ${request.method}: "$uri"',
        uri,
      );
      Logs().e('[ERROR] Invalid request URL', exception, stackTrace);
      return Future.error(exception, stackTrace);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
