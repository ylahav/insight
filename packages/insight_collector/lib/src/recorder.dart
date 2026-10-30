import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service_io.dart';

import 'attach.dart';

/// Connects to one Flutter VM Service and records a session.
class InsightCollector {
  const InsightCollector();

  Future<Map<String, Object?>> record({
    required String vmServiceUri,
    Duration duration = const Duration(seconds: 2),
    bool rebuilds = true,
  }) async {
    final service = await vmServiceConnectUri(
      convertToWebSocketUrl(serviceProtocolUrl: Uri.parse(vmServiceUri))
          .toString(),
    );
    final handle = InsightSessionHandle(service: service, rebuilds: rebuilds);
    try {
      await handle.start();
      await Future<void>.delayed(duration);
      await handle.stop();
      return handle.snapshot ?? handle.builder!.build();
    } finally {
      await service.dispose();
    }
  }
}
