// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class OidcPasswordTokens {
  const OidcPasswordTokens({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
  });

  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final int? expiresIn;

  factory OidcPasswordTokens.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : json;
    final accessToken = _readString(map, const ['access_token', 'accessToken']);
    if (accessToken == null || accessToken.isEmpty) {
      throw FormatException('OIDC login response is missing access_token');
    }
    return OidcPasswordTokens(
      accessToken: accessToken,
      idToken: _readString(map, const ['id_token', 'idToken']),
      refreshToken: _readString(map, const ['refresh_token', 'refreshToken']),
      expiresIn: _readInt(map, const ['expires_in', 'expiresIn']),
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
    }
    return null;
  }
}
