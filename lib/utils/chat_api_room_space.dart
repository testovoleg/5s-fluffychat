// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/custom_http_client.dart';

class ChatApiException implements Exception {
  const ChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _failed = 'chat_roomSpaceAttach failed';

// Без таймаута зависший шлюз держит окно загрузки до таймаута TCP
const Duration _timeout = Duration(seconds: 20);

/// Прикрепляет чат к пространству компании мутацией chat-api
/// `chat_roomSpaceAttach` через supergraph, когда у пользователя нет права
/// на `m.space.child` в пространстве.
///
/// Вызов без токена: chat-api прикрепляет чат, только если он ещё
/// не состоит ни в одном пространстве компании, и только к пространству
/// компании создателя чата.
///
/// Ошибки сети (`ClientException`) пропускаются как есть, чтобы
/// `toLocalizedString` показал «Нет связи с сервером».
Future<void> attachRoomToSpaceByChatApi({
  required String roomId,
  required String spaceId,
}) async {
  final httpClient = CustomHttpClient.createHTTPClient();
  try {
    final request = httpClient.post(
      Uri.parse(AppConfig.supergraphUrl),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'query': r'''
mutation RoomSpaceAttach($input: RoomSpaceAttachReq!) {
  chat_roomSpaceAttach(input: $input) {
    code
    success
    message
  }
}
''',
        'variables': {
          'input': {'synapseID': roomId, 'spaceSynapseID': spaceId},
        },
      }),
    );
    final response = await request.timeout(_timeout);
    final responseString = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      throw ChatApiException(
        '$_failed (${response.statusCode}): $responseString',
      );
    }

    final Object? json = jsonDecode(responseString);
    if (json is! Map) {
      throw ChatApiException('$_failed: $responseString');
    }

    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw ChatApiException(_message(errors.first));
    }

    final data = json['data'];
    final result = data is Map ? data['chat_roomSpaceAttach'] : null;
    if (result is! Map || result['success'] != true) {
      throw ChatApiException(_message(result));
    }
  } on FormatException catch (e) {
    throw ChatApiException(e.message);
  } finally {
    httpClient.close();
  }
}

String _message(Object? map) {
  final message = map is Map ? map['message'] : null;
  return message is String && message.isNotEmpty ? message : _failed;
}
