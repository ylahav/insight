import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/insight.dart';
import 'package:insight_bloc/insight_bloc.dart';

void main() {
  final messages = <Map<String, Object?>>[];
  late BlocObserver previous;

  setUp(() {
    messages.clear();
    Insight.captureStateValues = false;
    Insight.debugEventSink = messages.add;
    previous = Bloc.observer;
    Bloc.observer = InsightBlocObserver();
  });

  tearDown(() {
    Insight.captureStateValues = false;
    Insight.debugEventSink = null;
    Bloc.observer = previous;
  });

  test('a cubit change has a null event and a null value', () async {
    final cubit = CounterCubit();
    addTearDown(cubit.close);
    cubit.increment();

    expect(messages, hasLength(1));
    expect(messages.single['kind'], 'state.changed');
    expect(messages.single['adapter'], 'bloc');
    expect(messages.single['name'], 'CounterCubit');
    expect(messages.single['event'], isNull);
    expect(messages.single['summary'], 'int');
    expect(messages.single['value'], isNull);
  });

  test(
    'an equal bloc emit stays one record, and a real emit updates it',
    () async {
      final bloc = HostBloc();
      addTearDown(bloc.close);

      bloc.add(Stay());
      await _settle();
      expect(messages, hasLength(2));
      expect(messages[0]['timeUs'], messages[1]['timeUs']);
      expect(messages[1]['summary'], 'Idle');

      bloc.add(Stay());
      await _settle();
      expect(messages, hasLength(3));
      expect(messages.last['event'], 'Stay');
      expect(messages.last['summary'], 'Idle');

      bloc.add(Go());
      await _settle();
      expect(messages, hasLength(5));
      expect(messages[4]['timeUs'], messages[3]['timeUs']);
      expect(messages[3]['summary'], 'Idle');
      expect(messages[4]['summary'], 'Gone');
      expect(messages[4]['event'], 'Go');
    },
  );

  test('opt-in values are previous and next strings', () async {
    Insight.captureStateValues = true;
    final cubit = CounterCubit();
    addTearDown(cubit.close);
    cubit.increment();

    expect(messages.single['value'], {'previous': '0', 'next': '1'});
  });
}

Future<void> _settle() {
  return Future<void>.delayed(Duration.zero);
}

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class Stay {}

class Go {}

class Idle {}

class Gone {}

class HostBloc extends Bloc<Object, Object> {
  HostBloc() : super(Idle()) {
    on<Stay>((event, emit) => emit(state));
    on<Go>((event, emit) => emit(Gone()));
  }
}
