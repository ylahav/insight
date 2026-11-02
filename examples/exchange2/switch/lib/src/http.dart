import 'dart:convert';

import 'package:exchange2_agent/line_snapshot.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'actions.dart';

/// The switch HTTP server. The parked wait is not traced.
Handler switchHandler(SwitchActions actions) {
  final router = Router();

  router.post('/lines/<number>/register', (Request request, String number) {
    return _run(actions.register(_number(number)));
  });

  router.post('/lines/<number>/hook', (Request request, String number) async {
    final body = await _body(request);
    final off = body['off'];
    if (off is! bool) {
      return _error(400, 'off is true or false.');
    }
    return _run(actions.hook(_number(number), off: off));
  });

  router.post('/lines/<number>/digit', (Request request, String number) async {
    final body = await _body(request);
    final digit = body['digit'];
    if (digit is! String || digit.length != 1) {
      return _error(400, 'digit is one character.');
    }
    final value = int.tryParse(digit);
    if (value == null) {
      return _error(400, 'digit is one character.');
    }
    return _run(actions.digit(_number(number), value));
  });

  router.get('/lines/<number>/wait', (Request request, String number) {
    final after = int.tryParse(request.url.queryParameters['after'] ?? '');
    if (after == null) {
      return _error(400, 'after is a whole number.');
    }
    return _run(actions.wait(_number(number), after: after));
  });

  return router.call;
}

int _number(String number) => int.parse(number);

Future<Map<String, Object?>> _body(Request request) async {
  final text = await request.readAsString();
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
  return {};
}

Future<Response> _run(Future<Object> result) async {
  try {
    final snapshot = await result as LineSnapshot;
    return Response.ok(
      jsonEncode(snapshot.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  } on SwitchFailure catch (error) {
    return _error(error.status, error.message);
  } on FormatException catch (error) {
    return _error(400, error.message);
  }
}

Response _error(int status, String message) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: const {'content-type': 'application/json'},
  );
}
