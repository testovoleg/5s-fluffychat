// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/custom_http_client.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/sign_in_flows/oidc_password_tokens.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

class OidcPasswordLoginException implements Exception {
  const OidcPasswordLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Logs in via 5Systems OIDC password API, then completes Matrix login
/// the same way SSO does: `m.login.token` with the issued token.
Future<void> oidcPasswordLoginFlow({
  required Client client,
  required String username,
  required String password,
  String? totp,
}) async {
  final tokens = await requestOidcPasswordTokens(
    username: username,
    password: password,
    totp: totp,
  );

  try {
    await client.login(
      LoginType.mLoginToken,
      token: tokens.accessToken,
      initialDeviceDisplayName: PlatformInfos.appDisplayName,
    );
    return;
  } catch (e, s) {
    Logs().w(
      'Matrix m.login.token with OIDC access_token failed, trying JWT',
      e,
      s,
    );
  }

  final jwt = tokens.idToken ?? tokens.accessToken;
  await client.login(
    'org.matrix.login.jwt',
    token: jwt,
    initialDeviceDisplayName: PlatformInfos.appDisplayName,
  );
}

Future<OidcPasswordTokens> requestOidcPasswordTokens({
  required String username,
  required String password,
  String? totp,
}) async {
  final httpClient = CustomHttpClient.createHTTPClient();
  try {
    final input = <String, String>{
      'username': username,
      'password': password,
      if (totp != null && totp.isNotEmpty) 'totp': totp,
    };
    final response = await httpClient.post(
      Uri.parse(AppConfig.supergraphUrl),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'query': r'''
mutation OidcLogIn($username: String!, $password: String!, $totp: String) {
  auth_oidcLogIn(input: { username: $username, password: $password, totp: $totp }) {
    code
    success
    message
    data {
      accessToken
      expiresIn
      refreshToken
      refreshExpiresIn
    }
  }
}
''',
        'variables': input,
      }),
    );
    final responseString = utf8.decode(response.bodyBytes);
    Object? json;
    try {
      json = jsonDecode(responseString);
    } on FormatException {
      throw OidcPasswordLoginException(
        'OIDC login failed (${response.statusCode})',
      );
    }
    if (json is! Map) {
      throw OidcPasswordLoginException(
        'OIDC login failed (${response.statusCode})',
      );
    }
    final map = Map<String, dynamic>.from(json);
    if (response.statusCode >= 400) {
      throw OidcPasswordLoginException(
        'OIDC login failed (${response.statusCode})',
      );
    }

    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map
          ? first['message'] as String? ?? 'OIDC login failed'
          : 'OIDC login failed';
      throw OidcPasswordLoginException(message);
    }

    final data = map['data'];
    final login = data is Map ? data['auth_oidcLogIn'] : null;
    if (login is! Map) {
      throw const OidcPasswordLoginException('OIDC login failed');
    }
    final loginMap = Map<String, dynamic>.from(login);
    if (loginMap['success'] == false) {
      throw OidcPasswordLoginException(
        loginMap['message'] as String? ?? 'OIDC login failed',
      );
    }

    return OidcPasswordTokens.fromJson(loginMap);
  } on OidcPasswordLoginException {
    rethrow;
  } on FormatException catch (e) {
    throw OidcPasswordLoginException(e.message);
  } on http.ClientException catch (e) {
    throw OidcPasswordLoginException(e.message);
  } finally {
    httpClient.close();
  }
}
