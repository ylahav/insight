import 'dart:convert';
import 'dart:io';

import 'line_snapshot.dart';

/// The phone's client for the switch on port 8765.
class SwitchClient {
  SwitchClient(this.base);

  final Uri base;

  Future<LineSnapshot> register(int number) {
    return _send('POST', '/lines/$number/register');
  }

  Future<LineSnapshot> hook(int number, {required bool off}) {
    return _send(
      'POST',
      '/lines/$number/hook',
      body: {'off': off},
    );
  }

  Future<LineSnapshot> digit(int number, String digit) {
    return _send(
      'POST',
      '/lines/$number/digit',
      body: {'digit': digit},
    );
  }

  /// Held open until this line changes, or for 25 seconds.
  Future<LineSnapshot> wait(int number, {required int after}) {
    return _send('GET', '/lines/$number/wait?after=$after');
  }

  Future<LineSnapshot> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, base.resolve(path));
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await utf8.decoder.bind(response).join();
      final json = text.isEmpty
          ? <String, Object?>{}
          : jsonDecode(text) as Map<String, Object?>;
      if (response.statusCode >= 400) {
        final message = json['error'];
        throw SwitchException(
          response.statusCode,
          message is String ? message : 'The switch returned ${response.statusCode}.',
        );
      }
      return LineSnapshot.fromJson(json);
    } on SwitchException {
      rethrow;
    } on Object catch (error) {
      throw SwitchException(0, '$error');
    } finally {
      client.close();
    }
  }
}

class SwitchException implements Exception {
  SwitchException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}
