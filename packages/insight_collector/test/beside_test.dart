import 'package:insight_collector/insight_collector.dart';
import 'package:test/test.dart';

void main() {
  test('two ticks stay readable when their widgets differ', () {
    final scoped = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'second',
        'summary': 'int',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 1700, 'id': 'frame_159'},
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': 'TextButton'},
      {'type': 'widget.rebuild', 'timeUs': 130, 'name': 'SecondReadout'},
      {'type': 'widget.rebuild', 'timeUs': 140, 'name': 'Text'},
    ]);
    final wide = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 100,
        'name': 'second',
        'summary': 'int',
      },
      {'type': 'frame', 'timeUs': 110, 'elapsedUs': 1700, 'id': 'frame_69'},
      {'type': 'widget.rebuild', 'timeUs': 120, 'name': 'WideShelf'},
      {'type': 'widget.rebuild', 'timeUs': 130, 'name': 'SecondReadout'},
      {'type': 'widget.rebuild', 'timeUs': 140, 'name': 'MarkCard'},
      {'type': 'widget.rebuild', 'timeUs': 150, 'name': 'Padding'},
    ]);

    expect(scoped.single.title, 'second → int');
    expect(scoped.single.detail, '1.7 ms · frame_159');
    expect(scoped.single.widgets, ['SecondReadout']);
    expect(wide.single.widgets, ['WideShelf', 'SecondReadout', 'MarkCard']);
  });

  test('an ungrouped state stays in the list', () {
    final lines = besideLines([
      {
        'type': 'state.changed',
        'timeUs': 0,
        'name': 'tree',
        'summary': 'WideTree',
      },
      {'type': 'frame', 'timeUs': 32001, 'elapsedUs': 1000, 'id': 'frame_1'},
    ]);

    expect(lines.single.detail, 'ungrouped');
    expect(lines.single.title, 'tree → WideTree');
    expect(lines.single.widgets, isEmpty);
  });

  test('a span that overlaps two frames is listed once', () {
    final lines = besideLines([
      {
        'type': 'async.span',
        'name': 'loadBoard',
        'status': 'completed',
        'startUs': 100,
        'endUs': 500,
      },
      {'type': 'frame', 'timeUs': 100, 'elapsedUs': 200, 'id': 'frame_1'},
      {'type': 'frame', 'timeUs': 300, 'elapsedUs': 200, 'id': 'frame_2'},
    ]);

    expect(lines, hasLength(1));
    expect(lines.single.title, 'loadBoard → completed · 2 frames');
    expect(lines.single.detail, '0.2 ms · frame_1');
  });
}
