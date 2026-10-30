import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insight/insight.dart';

/// Posts `state.changed` when a provider emits a new value.
///
/// The first value is not a change, so [didAddProvider] is ignored.
/// `event` is null unless a Riverpod mutation is in progress. State strings
/// are included only when [Insight.captureStateValues] is set.
final class InsightRiverpodObserver extends ProviderObserver {
  const InsightRiverpodObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    Insight.stateChanged(
      adapter: 'riverpod',
      name: _providerName(context),
      event: _mutationName(context),
      summary: _typeName(newValue, 80),
      value: _values(previousValue, newValue),
    );
  }

  ({String? previous, String? next})? _values(Object? previous, Object? next) {
    if (!Insight.captureStateValues) {
      return null;
    }
    return (previous: _stateText(previous), next: _stateText(next));
  }
}

String _providerName(ProviderObserverContext context) {
  final label = context.provider.name;
  if (label != null && label.isNotEmpty) {
    return _clip(label, 120);
  }
  return _clip(context.provider.runtimeType.toString(), 120);
}

String? _mutationName(ProviderObserverContext context) {
  final mutation = context.mutation;
  if (mutation == null) {
    return null;
  }
  return _clip(mutation.runtimeType.toString(), 120);
}

String _typeName(Object? value, int max) {
  final name = value == null ? 'Null' : value.runtimeType.toString();
  return _clip(name, max);
}

String? _stateText(Object? value) {
  if (value == null) {
    return null;
  }
  return _clip(value.toString(), 120);
}

String _clip(String value, int max) {
  return value.length > max ? value.substring(0, max) : value;
}
