import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// Registers this process and runs the steps the Insight server sends.
class InsightAgent {
  InsightAgent({
    required this.server,
    required this.role,
    required this.name,
    required this.instance,
  });

  final Uri server;
  final String role;
  final String name;
  final String instance;

  var _stopped = false;

  Future<void> serve({
    required Future<void> Function(String target) onTap,
    required Future<String?> Function(String text) onSee,
  }) async {
    final vmServiceUri = await _vmUri();
    while (!_stopped) {
      try {
        await _register(vmServiceUri);
        break;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    while (!_stopped) {
      final command = await _poll();
      if (command == null) {
        continue;
      }
      var ok = true;
      String? error;
      try {
        if (command.command == 'tap') {
          await onTap(command.target ?? '');
        } else {
          error = await onSee(command.text ?? '');
          ok = error == null;
        }
      } on Object catch (failure) {
        ok = false;
        error = '$failure';
      }
      await _done(command.id, ok: ok, error: error);
    }
  }

  void stop() {
    _stopped = true;
  }

  Future<void> _register(String vmServiceUri) async {
    await _send('POST', '/register', {
      'role': role,
      'name': name,
      'instance': instance,
      'vmServiceUri': vmServiceUri,
    });
  }

  Future<_Command?> _poll() async {
    final response = await _send(
      'GET',
      '/next?name=$name&instance=$instance',
    );
    if (response == null) {
      return null;
    }
    return _Command.fromJson(response);
  }

  Future<void> _done(String id, {required bool ok, String? error}) {
    return _send('POST', '/done?name=$name&instance=$instance', {
      'id': id,
      'ok': ok,
      'error': ?error,
    }).then((_) {});
  }

  Future<Map<String, Object?>?> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, server.resolve(path));
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(const Duration(seconds: 40));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode == 204 || text.isEmpty) {
        return null;
      }
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) {
        return json;
      }
      if (json is Map) {
        return Map<String, Object?>.from(json);
      }
      return null;
    } finally {
      client.close();
    }
  }
}

Future<String> _vmUri() async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final info = await developer.Service.getInfo();
    final uri = info.serverUri;
    if (uri != null) {
      return uri.toString();
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return '';
}

class _Command {
  _Command({required this.id, required this.command, this.target, this.text});

  factory _Command.fromJson(Map<String, Object?> json) {
    return _Command(
      id: '${json['id']}',
      command: '${json['command']}',
      target: json['target'] as String?,
      text: json['text'] as String?,
    );
  }

  final String id;
  final String command;
  final String? target;
  final String? text;
}
