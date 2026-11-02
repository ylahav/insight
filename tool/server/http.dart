import 'dart:convert';
import 'dart:io';

import 'hub.dart';

/// Listens for registrations and for each program asking for its next step.
Future<HttpServer> serveHub(Hub hub, int port) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen((request) async {
    try {
      await _handle(hub, request);
    } on StateError catch (error) {
      await _json(request.response, 409, {'error': '$error'});
    } on FormatException catch (error) {
      await _json(request.response, 400, {'error': error.message});
    } on Object catch (error) {
      await _json(request.response, 500, {'error': '$error'});
    }
  });
  return server;
}

Future<void> _handle(Hub hub, HttpRequest request) async {
  final path = request.uri.path;
  if (request.method == 'POST' && path == '/register') {
    final body = await _body(request);
    final registration = Registration(
      role: _text(body, 'role'),
      name: _text(body, 'name'),
      instance: _text(body, 'instance'),
      vmServiceUri: _text(body, 'vmServiceUri'),
    );
    hub.register(registration);
    await _json(request.response, 200, {'id': registration.id});
    return;
  }

  final name = request.uri.queryParameters['name'];
  final instance = request.uri.queryParameters['instance'];
  if (name == null || instance == null) {
    throw const FormatException('name and instance are required.');
  }

  if (request.method == 'GET' && path == '/next') {
    final command = await hub.poll(name, instance);
    if (command == null) {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    await _json(request.response, 200, command.toJson());
    return;
  }

  if (request.method == 'POST' && path == '/done') {
    final body = await _body(request);
    final ok = body['ok'];
    if (ok is! bool) {
      throw const FormatException('ok is true or false.');
    }
    final error = body['error'];
    hub.complete(
      name,
      instance,
      _text(body, 'id'),
      ok: ok,
      error: error is String ? error : null,
    );
    await _json(request.response, 200, {'ok': true});
    return;
  }

  throw const FormatException('That request is not a scenario step.');
}

Future<Map<String, Object?>> _body(HttpRequest request) async {
  final text = await utf8.decoder.bind(request).join();
  if (text.isEmpty) {
    return {};
  }
  final json = jsonDecode(text);
  if (json is Map<String, Object?>) {
    return json;
  }
  if (json is Map) {
    return Map<String, Object?>.from(json);
  }
  throw const FormatException('The body is not an object.');
}

String _text(Map<String, Object?> json, String name) {
  final value = json[name];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$name is required.');
}

Future<void> _json(
  HttpResponse response,
  int status,
  Map<String, Object?> body,
) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
