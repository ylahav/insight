import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:insight_collector/insight_collector.dart';

import 'view.dart';

/// Lists a bloc change or a traced call, the frame that followed, and the
/// app widgets in that frame.
///
/// Counts and the wrapper filter are folded here. The session file does
/// not store them. Grouping is a time window, not a cause.
class InsightPanel extends StatefulWidget {
  const InsightPanel({super.key});

  @override
  State<InsightPanel> createState() => _InsightPanelState();
}

class _InsightPanelState extends State<InsightPanel> {
  InsightSessionHandle? _handle;
  Object? _error;
  var _generation = 0;
  var _hadSession = false;
  var _restarted = false;
  var _connecting = false;
  var _paused = false;
  var _showAllFrames = false;
  var _showAllWidgets = false;
  Map<String, Object?>? _held;

  @override
  void initState() {
    super.initState();
    serviceManager.connectedState.addListener(_onConnection);
    final connected = serviceManager.connectedState.value.connected;
    if (connected) {
      unawaited(_open(restart: false));
    }
  }

  @override
  void dispose() {
    serviceManager.connectedState.removeListener(_onConnection);
    final handle = _handle;
    _generation++;
    if (handle != null) {
      unawaited(handle.stop().catchError((Object _) {}));
    }
    super.dispose();
  }

  void _onConnection() {
    final connected = serviceManager.connectedState.value.connected;
    if (!connected) {
      _generation++;
      final handle = _handle;
      if (handle?.ready ?? false) {
        _hadSession = true;
      }
      _handle = null;
      unawaited(handle?.stop(strict: false));
      setState(() {
        _paused = false;
        _held = null;
      });
      return;
    }
    unawaited(_open(restart: _hadSession));
  }

  Future<void> _open({required bool restart}) async {
    final generation = ++_generation;
    final previous = _handle;
    _handle = null;
    try {
      await previous?.stop();
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _connecting = false;
        _error = error;
      });
      return;
    }
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
      _paused = false;
      _held = null;
      if (restart) {
        _restarted = true;
      }
    });
    try {
      await serviceManager.onServiceAvailable;
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _connecting = false;
        _error = error;
      });
      return;
    }
    if (!mounted || generation != _generation) {
      return;
    }
    final service = serviceManager.service;
    if (service == null) {
      setState(() => _connecting = false);
      return;
    }
    final handle = InsightSessionHandle(service: service);
    handle.onEvent = () {
      if (mounted && generation == _generation && !_paused) {
        setState(() {});
      }
    };
    _handle = handle;
    try {
      await handle.start();
    } catch (error) {
      if (generation == _generation) {
        _handle = null;
      }
      await handle.stop(strict: false);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _connecting = false;
        _error = error;
      });
      return;
    }
    if (!mounted || generation != _generation) {
      await handle.stop(strict: false);
      return;
    }
    setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    final connected = serviceManager.connectedState.value.connected;
    if (!connected && handle == null) {
      return const _Message('Waiting for the app.');
    }
    if (_error != null && (handle == null || !handle.ready)) {
      return _Message(_errorText(_error!));
    }
    if (handle == null || !handle.ready) {
      return _Message(_connecting ? 'Connecting.' : 'Waiting for the app.');
    }
    final snapshot = _paused ? _held : handle.snapshot;
    final events = (snapshot?['events'] as List?)?.whereType<Map>().map((
      event,
    ) {
      return Map<String, Object?>.from(event);
    });
    final grouping = groupFrames(events ?? const []);
    return _SessionView(
      mode: snapshot?['mode'] as String? ?? '',
      flutterVersion: snapshot?['flutter'] as String? ?? '',
      agentPresent: handle.agentPresent,
      restarted: _restarted,
      rejected: snapshot?['rejected'] as int? ?? 0,
      grouping: grouping,
      paused: _paused,
      showAllFrames: _showAllFrames,
      showAllWidgets: _showAllWidgets,
      onPause: _togglePause,
      onShowAllFrames: () {
        setState(() => _showAllFrames = !_showAllFrames);
      },
      onShowAllWidgets: () {
        setState(() => _showAllWidgets = !_showAllWidgets);
      },
    );
  }

  void _togglePause() {
    setState(() {
      if (_paused) {
        _paused = false;
        _held = null;
        return;
      }
      _paused = true;
      _held = _copySnapshot(_handle?.snapshot);
    });
  }
}

Map<String, Object?>? _copySnapshot(Map<String, Object?>? snapshot) {
  if (snapshot == null) {
    return null;
  }
  final copy = Map<String, Object?>.from(snapshot);
  final events = snapshot['events'];
  if (events is List) {
    copy['events'] = [
      for (final event in events)
        if (event is Map) _copyEvent(event),
    ];
  }
  return copy;
}

Map<String, Object?> _copyEvent(Map<dynamic, dynamic> event) {
  final copy = Map<String, Object?>.from(event);
  final value = copy['value'];
  if (value is Map) {
    copy['value'] = Map<String, Object?>.from(value);
  }
  return copy;
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.mode,
    required this.flutterVersion,
    required this.agentPresent,
    required this.restarted,
    required this.rejected,
    required this.grouping,
    required this.paused,
    required this.showAllFrames,
    required this.showAllWidgets,
    required this.onPause,
    required this.onShowAllFrames,
    required this.onShowAllWidgets,
  });

  final String mode;
  final String flutterVersion;
  final bool agentPresent;
  final bool restarted;
  final int rejected;
  final FrameGrouping grouping;
  final bool paused;
  final bool showAllFrames;
  final bool showAllWidgets;
  final VoidCallback onPause;
  final VoidCallback onShowAllFrames;
  final VoidCallback onShowAllWidgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = panelRows(
      grouping,
      showAllFrames: showAllFrames,
      showAllWidgets: showAllWidgets,
    );
    final extra = rows.states.length + rows.spans.length + rows.rebuilds.length;
    final hasRecords = rows.frames.isNotEmpty || extra > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mode · Flutter $flutterVersion · ${grouping.frames.length} frames',
            style: theme.textTheme.bodyMedium,
          ),
          if (!agentPresent) ...[
            const SizedBox(height: 8),
            Text(
              'The in-app package is absent. Frames are still shown.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (restarted) ...[
            const SizedBox(height: 8),
            Text(
              'The app restarted. This is a new session.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (rejected > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$rejected records were dropped.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: onPause,
                child: Text(paused ? 'Resume' : 'Pause'),
              ),
              TextButton(
                onPressed: onShowAllFrames,
                child: Text(showAllFrames ? 'Moments only' : 'Show all frames'),
              ),
              TextButton(
                onPressed: onShowAllWidgets,
                child: Text(
                  showAllWidgets ? 'App widgets' : 'Show all widgets',
                ),
              ),
            ],
          ),
          if (paused) ...[
            const SizedBox(height: 4),
            Text('The list is paused.', style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          Text(
            'Changes, earliest first. Time grouping, not a cause.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          if (!hasRecords)
            Text(
              showAllFrames
                  ? 'No user widgets rebuilt.'
                  : 'No bloc changes or traced calls yet.',
              style: theme.textTheme.bodyLarge,
            )
          else
            Expanded(
              child: _FlowList(
                steps: flowSteps(rows),
                outside: rows.rebuilds,
                paused: paused,
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowList extends StatefulWidget {
  const _FlowList({
    required this.steps,
    required this.outside,
    required this.paused,
  });

  final List<FlowStep> steps;
  final List<String> outside;
  final bool paused;

  @override
  State<_FlowList> createState() => _FlowListState();
}

class _FlowListState extends State<_FlowList> {
  final ScrollController _controller = ScrollController();
  var _count = 0;

  @override
  void initState() {
    super.initState();
    _count = widget.steps.length;
    _follow();
  }

  @override
  void didUpdateWidget(_FlowList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused || widget.steps.length == _count) {
      return;
    }
    _count = widget.steps.length;
    _follow();
  }

  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.outside.length;
    return ListView.builder(
      controller: _controller,
      itemCount: widget.steps.length + extra,
      itemBuilder: (context, index) {
        if (index >= widget.steps.length) {
          final name = widget.outside[index - widget.steps.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$name, outside a frame',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return _FlowStepTile(
          step: widget.steps[index],
          first: index == 0,
          last: index == widget.steps.length - 1,
        );
      },
    );
  }
}

class _FlowStepTile extends StatelessWidget {
  const _FlowStepTile({
    required this.step,
    required this.first,
    required this.last,
  });

  final FlowStep step;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.dividerColor;
    return Stack(
      children: [
        if (!(first && last))
          Positioned(
            left: 13,
            top: first ? 16 : 0,
            bottom: last ? null : 0,
            height: last ? 16 : null,
            child: Container(width: 2, color: line),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final state in step.states)
                      Text(
                        stateChange(state),
                        style: theme.textTheme.titleMedium,
                      ),
                    for (final item in step.spans)
                      Text(
                        spanChange(item.span, item.frames),
                        style: theme.textTheme.titleMedium,
                      ),
                    if (step.states.isEmpty && step.spans.isEmpty)
                      Text('Rebuild', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(_detail(step), style: theme.textTheme.bodySmall),
                    if (step.widgets.isNotEmpty || step.hiddenWidgets > 0) ...[
                      const SizedBox(height: 4),
                      for (final name in step.widgets.keys)
                        Text(
                          step.widgets[name] == 1
                              ? name
                              : '$name  ${step.widgets[name]}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      if (step.hiddenWidgets > 0)
                        Text(
                          step.hiddenWidgets == 1
                              ? '1 wrapper hidden'
                              : '${step.hiddenWidgets} wrappers hidden',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

String _detail(FlowStep step) {
  if (step.ungrouped) {
    return 'ungrouped';
  }
  final elapsed = step.elapsedUs;
  final time = elapsed == null
      ? ''
      : '${(elapsed / 1000).toStringAsFixed(1)} ms';
  final id = step.frameId ?? '';
  if (time.isEmpty) {
    return id;
  }
  if (id.isEmpty) {
    return time;
  }
  return '$time · $id';
}

String _errorText(Object error) {
  if (error is StateError) {
    return error.message;
  }
  return '$error';
}
