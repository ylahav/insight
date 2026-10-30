import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insight/insight.dart';

/// Posts `state.changed` for blocs and cubits.
///
/// A bloc event is recorded from `onEvent`, with [summary] set to the current
/// state type. A later transition for that same event updates the record
/// instead of posting a second one. A cubit has no event, so `event` is null.
/// State strings are included only when [Insight.captureStateValues] is set.
class InsightBlocObserver extends BlocObserver {
  InsightBlocObserver();

  /// `timeUs` of the `onEvent` post, keyed by the event instance.
  ///
  /// An [Expando] does not retain the event. Bloc 9.0, which `flutter_bloc`
  /// 9.1.1 allows, has no `onDone` to clear a normal map, and a retained
  /// event can hold fields such as a password.
  final Expando<int> _open = Expando<int>();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event == null) {
      return;
    }
    _open[event] = Insight.stateChanged(
      adapter: 'bloc',
      name: _typeName(bloc, 120),
      event: _typeName(event, 120),
      summary: _typeName(bloc.state, 80),
    );
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    final event = transition.event;
    final name = _typeName(bloc, 120);
    final eventName = event == null ? null : _typeName(event, 120);
    final summary = _typeName(transition.nextState, 80);
    final value = _values(transition.currentState, transition.nextState);
    final timeUs = event == null ? null : _open[event];
    if (timeUs == null) {
      Insight.stateChanged(
        adapter: 'bloc',
        name: name,
        event: eventName,
        summary: summary,
        value: value,
      );
      return;
    }
    Insight.reviseState(
      timeUs: timeUs,
      adapter: 'bloc',
      name: name,
      event: eventName,
      summary: summary,
      value: value,
    );
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (bloc is Bloc) {
      return;
    }
    Insight.stateChanged(
      adapter: 'bloc',
      name: _typeName(bloc, 120),
      event: null,
      summary: _typeName(change.nextState, 80),
      value: _values(change.currentState, change.nextState),
    );
  }

  ({String? previous, String? next})? _values(Object? previous, Object? next) {
    if (!Insight.captureStateValues) {
      return null;
    }
    return (previous: _stateText(previous), next: _stateText(next));
  }
}

String _typeName(Object? value, int max) {
  final name = value == null ? 'Null' : value.runtimeType.toString();
  return name.length > max ? name.substring(0, max) : name;
}

String? _stateText(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.length > 120 ? text.substring(0, 120) : text;
}
