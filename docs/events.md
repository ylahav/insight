# Event model

Schema version **1**. The collector writes this model. The DevTools extension and the CLI both read it. Agent code posts a smaller wire message, and the collector assigns timestamps, ids, and the session envelope.

Readers ignore unknown fields. A missing required field rejects that event. A `schemaVersion` other than `1` rejects that event. Rejected events increment `rejected` and are dropped from `events`. The rest of the session is kept.

## Session file

The CLI writes `insight-session.json` in the working directory. The extension holds the same object in memory.

```json
{
  "schemaVersion": 1,
  "flutter": "3.47.8",
  "dart": "3.13.7",
  "mode": "profile",
  "startedAt": "2026-10-28T06:00:00Z",
  "events": [],
  "rejected": 0
}
```

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `schemaVersion` | integer | yes | `1` |
| `flutter` | string | yes | Version reported by the connected VM, such as `3.47.8` or `3.44.9` |
| `dart` | string | yes | Dart version reported alongside Flutter |
| `mode` | string | yes | `debug` or `profile` |
| `startedAt` | string | yes | UTC time the collector connected, ISO-8601 |
| `events` | array | yes | Sorted by the rule below. Empty is valid |
| `rejected` | integer | yes | Count of agent or timeline records the collector dropped |

`mode` is never `release`. The collector does not open a session for a release isolate.

`play` is optional. `tool/play.dart` adds it after the collector writes the envelope. A reader that does not know the field leaves it unread.

```json
"play": {
  "board": "bloc",
  "scenarioPath": "examples/exchange/ring.txt",
  "scenario": "tap lines-3\n",
  "commit": "fd4cf670824a92d12d8007a139341e9c0346afcb",
  "branch": "main",
  "subject": "Point the repository at ylahav/insight.",
  "scenarioDirty": false
}
```

`scenario` is the tap file that was played. `board` is `bloc`, `riverpod`, or `plinth`. `commit`, `branch`, `subject`, and `scenarioDirty` are the git state of that file when the recording was made. Compare uses the text of `scenario`, not the path alone, to decide that two recordings played the same taps. Analyzer reads this one session, and Add result reads another.

### Sort order

Events are ordered by `timeUs` ascending. `async.span` uses `startUs` as its sort key. When two timestamps are equal, the order is:

1. `agent.ready`
2. `user.action`
3. `state.changed`
4. `async.span`
5. `widget.rebuild`
6. `frame`

### Identifiers

The collector assigns `id`. The form is a type prefix, an underscore, and a decimal counter unique within the session: `frame_1`, `widget_1`, `state_1`, `async_1`, `agent_1`, `action_1`.

The agent assigns `spanId` for async work so the collector can merge a start and an end. `spanId` is an opaque string of at most 80 characters. It is not the session `id`.

## Record types

Timestamps are timeline microseconds from `Timeline.now`. `Flutter.Frame` reports frame start on that same clock, in `startTime`. The Extension event's own timestamp is wall-clock microseconds and is not used for ordering. The agent puts `timeUs` in every wire message.

### `agent.ready`

Posted once when the in-app binding attaches.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"agent.ready"` | yes | |
| `id` | string | yes | |
| `timeUs` | integer | yes | `Timeline.now` at the post |
| `schemaVersion` | integer | yes | Wire version. `1` in v1 |

`schemaVersion` here is the agent wire version. The collector rejects the session's agent stream when this value is not `1`, and records frames only.

### `frame`

One record per Flutter frame the collector observed.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"frame"` | yes | |
| `id` | string | yes | |
| `timeUs` | integer | yes | Frame start |
| `buildUs` | integer | yes | UI thread build duration, `>= 0` |
| `rasterUs` | integer | yes | Raster duration, `>= 0` |
| `elapsedUs` | integer | yes | Frame elapsed time, `>= 0` |
| `targetUs` | integer or null | yes | Vsync interval when the collector could read it |
| `budgetExceeded` | boolean or null | yes | `true` when `elapsedUs > targetUs`. `null` when `targetUs` is `null` |

The collector does not assume a 16.6 ms budget. A 120 Hz panel and a 60 Hz panel stay honest because a missing interval is `null`, not a guess.

### `widget.rebuild`

One record per observed user-widget build. The UI counts records. The file does not store a running total.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"widget.rebuild"` | yes | |
| `id` | string | yes | |
| `timeUs` | integer | yes | |
| `name` | string | yes | Widget runtime type, truncated to 120 characters |
| `library` | string | no | Library URI when the timeline event includes one |

There is no `cause` field in version 1. A name and a timestamp is the whole observation. Build durations from these timeline events are discarded. Flutter's own documentation treats that overhead as large enough to distort the cost of the build.

### `user.action`

The app posts this when the user taps a control. The exchange board posts the same name the play script uses, such as `phone-1` or `digit-1-2`. A manual run posts it too. The file does not infer the tap from a rebuild.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"user.action"` | yes | |
| `id` | string | yes | |
| `timeUs` | integer | yes | `Timeline.now` at the tap |
| `name` | string | yes | The control. Truncated to 80 characters |

Analyzer prints `tap` and that name above the earliest step at or after `timeUs`, when the gap is at most 32 ms. A wider gap leaves the action off the step. That placement is the same time window as a state change. It is not a cause.

### `state.changed`

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"state.changed"` | yes | |
| `id` | string | yes | |
| `timeUs` | integer | yes | |
| `adapter` | string | yes | `bloc` or `riverpod` |
| `name` | string | yes | Bloc or Cubit runtime type, or the Riverpod provider's `name` when set and otherwise its runtime type. Truncated to 120 characters. Example: `BoardBloc` |
| `event` | string or null | yes | Runtime type of the bloc event, or of the Riverpod mutation when one is in progress. Truncated to 120 characters. `null` for a Cubit and for a Riverpod update with no mutation. Fields on the event or mutation are never included |
| `summary` | string | yes | State runtime type, truncated to 80 characters. Example: `BoardReady` |
| `value` | object or null | yes | `null` unless the app opted in |

When the app sets `Insight.captureStateValues = true`, `value` is:

```json
{ "previous": "0", "next": "1" }
```

Both strings are required in that object, already produced by the adapter, and truncated to 120 characters. The collector truncates again if the agent did not. `null` inside `previous` or `next` means the adapter had no value, and is distinct from a `value` of `null` on the event.

Default sessions omit the contents of state. The bloc type, the event type, and the state type are enough to line the update up with a frame. An event object can hold a password or a token. Those fields are not part of this record.

Bloc does not call `onChange` when `emit` is given a state that compares equal to the current one and a state was already emitted. The observer still writes a record from `onEvent`, with `summary` set to the current state type, so that case is not silent. A later transition for the same event updates that record's `summary` instead of writing a second one. The agent posts that update as another `state.changed` with the same `timeUs`, `name`, and `event`. The collector replaces `summary` and `value` on the existing record.

### `async.span`

The agent posts `async.start` and `async.end` with the same `spanId`. The collector emits one record. A start that never ends before the session closes is kept.

| Field | Type | Required | Rule |
| --- | --- | --- | --- |
| `type` | `"async.span"` | yes | |
| `id` | string | yes | |
| `name` | string | yes | Caller-supplied name, or `future` / `stream`. Truncated to 80 characters |
| `startUs` | integer | yes | |
| `endUs` | integer or null | yes | `null` when unfinished |
| `status` | string | yes | `completed`, `error`, or `unfinished` |
| `error` | string or null | yes | Truncated to 200 characters. `null` unless `status` is `error` |

An `error` status still has `endUs` set. `unfinished` has `endUs: null` and `error: null`. Stack traces are not part of version 1.

## Agent wire message

`developer.postEvent('Insight.Event', message)`. One event kind. `postEvent` does nothing until a client is listening, so the collector calls `ext.insight.agent` after it subscribes. That call posts `agent.ready`. Every message carries `timeUs` from `Timeline.now`.

```json
{
  "schemaVersion": 1,
  "kind": "agent.ready",
  "timeUs": 1000
}
```

```json
{
  "schemaVersion": 1,
  "kind": "user.action",
  "timeUs": 499000,
  "name": "phone-1"
}
```

```json
{
  "schemaVersion": 1,
  "kind": "state.changed",
  "timeUs": 500000,
  "adapter": "bloc",
  "name": "BoardBloc",
  "event": "TicketSelected",
  "summary": "BoardReady",
  "value": null
}
```

```json
{
  "schemaVersion": 1,
  "kind": "async.start",
  "timeUs": 120000,
  "spanId": "fetch-1",
  "name": "fetchData"
}
```

```json
{
  "schemaVersion": 1,
  "kind": "async.end",
  "timeUs": 150000,
  "spanId": "fetch-1",
  "status": "completed",
  "error": null
}
```

`async.end` `status` is `completed` or `error`. The collector is the only writer of `unfinished`.

The collector drops an agent message larger than 8 KB and increments `rejected`. Adapters send summaries, not widget trees or response bodies.

## Same-frame grouping

Grouping is a UI rule. The session file does not store links between records, because a link would look like a cause.

- A `widget.rebuild` belongs to the `frame` whose interval `[timeUs, timeUs + elapsedUs]` contains the rebuild time.
- An `async.span` belongs to every frame that overlaps `[startUs, endUs]` (`endUs` is the session end when the span is unfinished).
- A `state.changed` belongs to the earliest frame with `timeUs` greater than or equal to the state time, when the gap is at most **32 ms** (`32000` microseconds). Otherwise it stays ungrouped.

That 32 ms window exists because a bloc transition is timestamped before the frame it schedules. The panel calls this grouping, not a cause. Version 1 has no inferred-cause label.

## Example

Selecting a ticket on the desk. `BoardBloc` handles `TicketSelected` and emits `BoardReady`. State values are off. `TicketDetail` is the user widget that build emitted.

```json
{
  "schemaVersion": 1,
  "flutter": "3.47.8",
  "dart": "3.13.7",
  "mode": "profile",
  "startedAt": "2026-10-28T06:00:00Z",
  "rejected": 0,
  "events": [
    {
      "type": "agent.ready",
      "id": "agent_1",
      "timeUs": 1000,
      "schemaVersion": 1
    },
    {
      "type": "state.changed",
      "id": "state_1",
      "timeUs": 500000,
      "adapter": "bloc",
      "name": "BoardBloc",
      "event": "TicketSelected",
      "summary": "BoardReady",
      "value": null
    },
    {
      "type": "frame",
      "id": "frame_1",
      "timeUs": 500800,
      "buildUs": 2100,
      "rasterUs": 1400,
      "elapsedUs": 4200,
      "targetUs": 16667,
      "budgetExceeded": false
    },
    {
      "type": "widget.rebuild",
      "id": "widget_1",
      "timeUs": 501200,
      "name": "TicketDetail",
      "library": "package:desk/src/widgets.dart"
    }
  ]
}
```

`state_1` groups with `frame_1` because the frame starts 0.8 ms later, inside the 32 ms window. `widget_1` groups with `frame_1` because it falls inside that frame's elapsed interval. Nothing in the file says the bloc event caused the rebuild.

## Left out of version 1 on purpose

- Cause labels and confidence scores
- Running rebuild counts
- Widget-build durations
- Full state values by default
- Stack traces
- Platform channel or FFI logs
- Links or edges between records
- A pass/fail field for CI
