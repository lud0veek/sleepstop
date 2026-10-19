# Service-Isolate Sleep Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the sleep-detection engine inside the foreground service's own Flutter isolate so a night survives the app being closed, the screen off, Doze, and a process kill followed by a service restart, with the UI acting as a live mirror.

**Architecture:** The existing `SleepSessionNotifier` (and the whole Riverpod graph it needs) is instantiated in the `TaskHandler` of `flutter_foreground_task` via a headless `ProviderContainer`; its state is serialized to the UI isolate, which drives it through a small command protocol. All native bridges move into a local Flutter plugin so both engines (UI and service) reach them. A persisted snapshot lets a restarted service resume the night.

**Tech Stack:** Flutter 3.41 / Dart 3.11, Riverpod 3 (`ProviderContainer` without widgets), flutter_foreground_task 10 (`TaskHandler.onReceiveData`, `sendDataToMain`, `sendDataToTask`), Kotlin 2.2 local plugin (`FlutterPlugin` + `ActivityAware`), SharedPreferences, `ApplicationExitInfo` (API 30+).

**Spec:** `specs/2026-10-19-service-isolate-engine-design.md`

**Plan location note:** `docs/` is published by Firebase Hosting, so plans live in `specs/plans/` instead of `docs/superpowers/plans/`.

## Global Constraints

- minSdk 26, targetSdk 36, Kotlin 2.2.20, AGP 8.11.1 — unchanged.
- Target version after this plan: `1.1.0+4` (`pubspec.yaml` + `lib/app_info.dart`).
- Method channel names stay `com.sleepstop/media_control` and `com.sleepstop/home_actions` (Dart services untouched).
- Detection algorithm, grace window, night veil, "When I fall asleep" module, screens and strings do not change; the 56 existing tests stay green.
- No new pub dependency. The Google Home AAR folder moves with the Kotlin code to `packages/sleepstop_native/android/libs/homeapis/` (still git-ignored).
- Mirror messages ≤ 2 per second; snapshot written every 30 s; resume allowed only if the snapshot is < 8 h old; resumed sessions start in `monitoring`, never in `fadingAudio` or `graceWindow`, and never touch the media.
- Heartbeat considered stale after 20 s.
- Logs in release never contain device ids, URLs or secrets (existing rule).

## Review Focus

1. **Service started by the system before any UI exists** (sticky restart at 00:00): `onStart(system)` must never touch a `ProviderContainer` that reads widgets or `FlutterForegroundTask.sendDataToMain` before `initCommunicationPort` — Task 4 test `resume decision without a UI` covers it.
2. **Command arrives before the engine host exists** (UI sends `start` right after `startService`): the host must queue or the UI must wait for the first `state`/`ready` event — Task 3 test `start command sent before ready is applied once ready`.
3. **Two engines, one plugin instance per engine**: a tile toggle while both engines are alive must reach the service engine, not the UI one — Task 1 test `NativeBridge prefers the background channel`.
4. **Snapshot older than 8 h or from a finished night** must not resume (user woke up, ate breakfast, service restarted): Task 4 test `stale snapshot is not resumed`.
5. **Kill detection must not blame Android for our own force-stops** (`USER_REQUESTED`, `PACKAGE_UPDATED`, `CRASH` are not "interruptions"): Task 5 test `only SIGNALED/LOW_MEMORY/OTHER during a session count`.

---

### Task 1: Local native plugin shared by both engines

**Files:**
- Create: `packages/sleepstop_native/pubspec.yaml`, `packages/sleepstop_native/lib/sleepstop_native.dart`, `packages/sleepstop_native/android/build.gradle.kts`, `packages/sleepstop_native/android/src/main/AndroidManifest.xml`
- Create: `packages/sleepstop_native/android/src/main/kotlin/com/sleepstop/sleepstop_native/SleepstopNativePlugin.kt`, `.../NativeBridge.kt`, `.../MediaControlHandler.kt`
- Move (git mv, package renamed to `com.sleepstop.sleepstop_native`): `NightOverlay.kt`, `homeactions/HomeActionsChannel.kt`, `homeactions/LightsController.kt`, `src/homeapis/...`, `src/homeapis-stub/...`, `libs/homeapis/{README.md,.gitignore}`
- Modify: `android/app/src/main/kotlin/com/sleepstop/sleep_stop/MainActivity.kt` (keep only tile intent routing + `onCreate` bind), `.../SleepStopTileService.kt` (call `NativeBridge`), `android/app/build.gradle.kts` (remove Home APIs block), `pubspec.yaml` (`sleepstop_native: path: packages/sleepstop_native`), `specs/2026-10-19-google-home-setup.md` (new AAR path)
- Test: `packages/sleepstop_native/android/src/test/kotlin/com/sleepstop/sleepstop_native/NativeBridgeTest.kt`

**Interfaces:**
- Consumes: nothing new.
- Produces (Kotlin, used by Tasks 3–5):
  - `object NativeBridge { fun registerChannel(engineId: String, channel: MethodChannel, hasActivity: Boolean); fun unregisterChannel(engineId: String); fun dispatchQuickTileToggle(): Boolean; fun dispatchStillAwake(): Boolean; fun invokeOnBackgroundFirst(method: String, args: Any?): Boolean }`
  - `class SleepstopNativePlugin : FlutterPlugin, ActivityAware` registering `MediaControlHandler(context)` on `com.sleepstop/media_control` and `HomeActionsChannel(context)` on `com.sleepstop/home_actions` for every engine; `currentActivity: Activity?` exposed to handlers needing one (`requestRuntimePermissions`, `requestAddQuickSettingsTile`, Google Home `bindActivity`).
- Produces (Dart): package `sleepstop_native` with an empty library (registration only; Dart keeps using `MethodChannel` directly).

- [ ] **Step 1: Write the failing Kotlin unit test**

```kotlin
class NativeBridgeTest {
  @Test fun prefersBackgroundChannelForTileToggle() {
    val ui = mockk<MethodChannel>(relaxed = true); val bg = mockk<MethodChannel>(relaxed = true)
    NativeBridge.registerChannel("ui", ui, hasActivity = true)
    NativeBridge.registerChannel("bg", bg, hasActivity = false)
    assertTrue(NativeBridge.dispatchQuickTileToggle())
    verify { bg.invokeMethod("onQuickTileToggle", null) }
    verify(exactly = 0) { ui.invokeMethod("onQuickTileToggle", null) }
  }
  @Test fun fallsBackToUiChannelThenFalse() { /* only ui registered → ui invoked; none → returns false */ }
}
```
Add `testImplementation("io.mockk:mockk:1.13.13")` and `testImplementation("junit:junit:4.13.2")` to the plugin's `build.gradle.kts`.

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd packages/sleepstop_native/android && gradle test` (or `./gradlew :sleepstop_native:testDebugUnitTest` from `android/` after Step 4). Expected: FAIL, `NativeBridge` unresolved.

- [ ] **Step 3: Create the plugin skeleton**

`pubspec.yaml`: name `sleepstop_native`, `flutter: plugin: platforms: android: package: com.sleepstop.sleepstop_native, pluginClass: SleepstopNativePlugin`. `android/build.gradle.kts`: `com.android.library`, `kotlin-android`, namespace `com.sleepstop.sleepstop_native`, compileSdk/minSdk from the app, `dependencies { implementation("androidx.core:core-ktx:1.15.0") }`, plus the Home APIs conditional block copied verbatim from `android/app/build.gradle.kts` lines 17–23/30–34/42–48/70–76 with `libs/homeapis` now relative to the plugin module. Manifest: `<uses-permission SYSTEM_ALERT_WINDOW/>` moves here (the app manifest keeps its copy; duplicates merge).

- [ ] **Step 4: Implement `NativeBridge` and `SleepstopNativePlugin`**

`NativeBridge` keeps a `LinkedHashMap<String, Pair<MethodChannel, Boolean>>`; `invokeOnBackgroundFirst` posts on the main looper, tries the first entry with `hasActivity == false`, else the first with `true`, returns whether one was found. `SleepstopNativePlugin.onAttachedToEngine` creates both channels with `binding.applicationContext`, registers with `engineId = System.identityHashCode(binding.flutterEngine).toString()`, `hasActivity = false`; `onAttachedToActivity` flips the flag for that engine and stores the activity; `onDetachedFromActivity` clears it; `onDetachedFromEngine` unregisters.

- [ ] **Step 5: Move `MainActivity`'s media/volume/apps/overlay handlers into `MediaControlHandler(context, activityProvider: () -> Activity?)`**

Same method names and results as today (`pauseMedia`, `resumeMedia`, `rewindMedia`, `getCurrentVolume`, `getMaxVolume`, `setVolume`, `isMusicActive`, `getActiveMediaInfo`, `isNotificationListenerEnabled`, `openNotificationListenerSettings`, `getInstalledApps`, `closeTargetApps`, `requestRuntimePermissions`, `updateQuickTileState`, `consumeQuickTileLaunchTrigger`, `requestAddQuickSettingsTile`, `canDrawOverlays`, `openOverlayPermissionSettings`, `showNightOverlay`, `updateNightOverlay`, `finalizeNightOverlay`, `hideNightOverlay`). `startActivity` calls add `FLAG_ACTIVITY_NEW_TASK` (application context). `requestRuntimePermissions` and `requestAddQuickSettingsTile` return `"NO_ACTIVITY"` / `false` when `activityProvider()` is null. The quick-tile pending flag (`pendingQuickTileToggle`) and `checkQuickTileIntent` stay in `MainActivity`, which now calls `NativeBridge.dispatchQuickTileToggle()`. `SleepStopTileService.onClick` calls `NativeBridge.dispatchQuickTileToggle()`; `NightOverlay` tap calls `NativeBridge.dispatchStillAwake()`.

- [ ] **Step 6: Wire the app**

`pubspec.yaml` path dependency; `flutter pub get`; delete the moved Kotlin from `android/app`; strip the Home APIs block from `android/app/build.gradle.kts`; `MainActivity.configureFlutterEngine` no longer registers channels (the plugin does); `MainActivity.onCreate` keeps `HomeActionsChannel.bindActivity(this)` via `NativeBridge`/plugin `currentActivity`.

- [ ] **Step 7: Verify**

Run: `flutter pub get && flutter analyze && flutter test` → `No issues found`, `+56`. Run: `flutter build apk --debug` → builds; `grep SleepstopNativePlugin android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` → one line. Kotlin test from Step 1 → PASS. On device (debug build): dashboard volume fade test and night veil still work (manual).

- [ ] **Step 8: Commit**

```bash
git add packages pubspec.yaml pubspec.lock android specs
git commit -m "refactor(native): move all bridges into the sleepstop_native plugin, registered on every engine"
```

---

### Task 2: Serializable session state

**Files:**
- Modify: `lib/models/active_session_state.dart`
- Test: `test/active_session_state_json_test.dart`

**Interfaces:**
- Produces: `Map<String, dynamic> ActiveSessionState.toJson()`, `factory ActiveSessionState.fromJson(Map<String, dynamic>)`, `Map<String, dynamic> DiscoveredBleWatch.toJson()`, `factory DiscoveredBleWatch.fromJson(...)`. Enums serialized by `.name`; `DateTime` as ISO 8601 UTC; unknown enum names fall back to `idle` / `watchBle`.

- [ ] **Step 1: Write the failing test**

```dart
test('round-trips every field', () {
  final s = ActiveSessionState(isRunning: true, phase: SessionPhase.graceWindow, activeMode: DetectionMode.phoneFadeShake,
    statusText: 'x', detailText: 'y', sessionStartTime: DateTime.utc(2026,10,19,22), elapsedSeconds: 42,
    connectedWatchName: 'Fenix', connectedWatchId: 'AA', currentBpm: 58, baselineBpm: 64.5, effectiveThresholdBpm: 57,
    bpmStabilityStdDev: 1.2, latestRrIntervalMs: 1010, hrvRmssdMs: 33.3, sleepConfidenceScore: 0.5,
    consecutiveLowHrSeconds: 10, requiredLowHrSeconds: 240,
    discoveredWatches: const [DiscoveredBleWatch(id: 'AA', name: 'Fenix', rssi: -50, advertisesHrService: true)],
    calibrationProgress: 0.7, signalLostSeconds: 3, graceRemainingSeconds: 80, stillAwakeCount: 1, bpmTimeline: const [60, 58],
    checkIntervalRemainingSeconds: 100, checkIntervalTotalSeconds: 900, lastShakeMagnitude: 0.4, shakeResetCount: 2,
    isFading: false, fadeRemainingSeconds: 0, fadeTotalSeconds: 10, originalVolume: 8, currentVolume: 4, maxVolume: 15);
  final back = ActiveSessionState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
  expect(back.phase, SessionPhase.graceWindow); expect(back.sessionStartTime, s.sessionStartTime);
  expect(back.discoveredWatches.single.rssi, -50); expect(back.bpmTimeline, [60, 58]); expect(back.maxVolume, 15);
});
test('unknown phase name falls back to idle', () => expect(ActiveSessionState.fromJson({'phase': 'nope'}).phase, SessionPhase.idle));
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/active_session_state_json_test.dart` → FAIL (`toJson` undefined).
- [ ] **Step 3: Implement `toJson` / `fromJson`** in `active_session_state.dart` (one key per field, same names as the Dart fields).
- [ ] **Step 4: Run to verify pass** — same command → `+2`.
- [ ] **Step 5: Commit** — `git commit -am "feat(state): JSON serialization of ActiveSessionState"`.

---

### Task 3: Engine host in the service + UI mirror

**Files:**
- Create: `lib/service/session_engine_host.dart`, `lib/service/session_protocol.dart`, `lib/providers/session_mirror_provider.dart`
- Modify: `lib/services/foreground_task_service.dart` (TaskHandler hosts the engine), `lib/ui/dashboard_tab.dart:36-39`, `lib/ui/settings_screen.dart:35,98`, `lib/ui/home_screen.dart` (read `sessionMirrorProvider` instead of the dispatcher), `lib/providers/sleep_session_provider.dart` (expose `handleCommand`; `startSession` no longer starts the service itself — the host does)
- Test: `test/session_protocol_test.dart`, `test/session_engine_host_test.dart`, `test/session_mirror_provider_test.dart`

**Interfaces:**
- Produces `lib/service/session_protocol.dart`:
  - `class SessionCommand { final String cmd; final Map<String, dynamic> args; Map<String, dynamic> toMessage(); static SessionCommand? fromMessage(Object data); }` with `cmd ∈ {start, stop, stillAwake, selectMode, testFade, manualWake, sync, testAction}`; `start` args `{mode: DetectionMode.name, simulate: bool}`, `selectMode` args `{mode}`, `testAction` args `{id}`.
  - `class ServiceEvent { final String event; final Map<String, dynamic> data; }` with `event ∈ {ready, state, heartbeat, actionStatus, resumed, interrupted}`; `state.data = {'state': ActiveSessionState json}`; `heartbeat.data = {'at': iso}`; `actionStatus.data = {'id', 'outcome', 'message', 'at'}`.
- Produces `lib/service/session_engine_host.dart`: `class SessionEngineHost { SessionEngineHost({required void Function(Object) send, ProviderContainer? container}); Future<void> start(); void handleCommand(SessionCommand c); Future<void> dispose(); ProviderContainer get container; }`. `start()` reads `sleepSessionProvider` and `sleepActionDispatcherProvider`, listens to the session state and sends `state` events throttled to 500 ms (always sending the final value), sends `ready` once.
- Produces `lib/providers/session_mirror_provider.dart`: `sessionMirrorProvider = NotifierProvider<SessionMirrorNotifier, ActiveSessionState>` with the exact method names the UI already calls: `Future<void> startSession({bool simulateBleWatch = false})`, `Future<void> stopSession()`, `Future<void> stillAwake()`, `void selectMode(DetectionMode)`, `Future<void> triggerFadeNowForTesting()`, `Future<void> triggerManualWakeReset()`, `Future<String> requestAddQuickTile()`; plus `DateTime? get lastHeartbeatAt`, `bool get serviceAlive` (heartbeat < 20 s). `startSession` calls `ForegroundTaskService.instance.startMonitoringService(title, text)` when `!isRunningService`, then queues `start` until a `ready` event arrives.
- Consumes: Task 2 JSON; `FlutterForegroundTask.sendDataToTask/sendDataToMain/addTaskDataCallback`.

- [ ] **Step 1: Write the failing protocol test**

```dart
test('command and event messages round-trip', () {
  final c = SessionCommand.start(mode: DetectionMode.watchBle, simulate: true);
  expect(SessionCommand.fromMessage(c.toMessage())!.args['simulate'], true);
  expect(SessionCommand.fromMessage({'foo': 1}), isNull);
  final e = ServiceEvent.state(const ActiveSessionState(isRunning: true));
  expect(ServiceEvent.fromMessage(e.toMessage())!.event, 'state');
});
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/session_protocol_test.dart` → FAIL.
- [ ] **Step 3: Implement `session_protocol.dart`** (pure Dart, no Flutter imports).
- [ ] **Step 4: Run to verify pass.**

- [ ] **Step 5: Write the failing host test**

```dart
test('start command sent before ready is applied once ready', () async {
  final sent = <Object>[];
  final host = SessionEngineHost(send: sent.add, container: ProviderContainer(overrides: [/* storage with SharedPreferences.setMockInitialValues */]));
  host.handleCommand(SessionCommand.start(mode: DetectionMode.watchBle, simulate: true)); // before start()
  await host.start();
  await Future<void>.delayed(const Duration(milliseconds: 700));
  expect(sent.any((m) => (m as Map)['event'] == 'ready'), isTrue);
  final last = ServiceEvent.fromMessage(sent.lastWhere((m) => (m as Map)['event'] == 'state'))!;
  expect(ActiveSessionState.fromJson(last.data['state']).isRunning, isTrue);
  await host.dispose();
});
test('state events are throttled to at most 2 per second', () async { /* drive 20 state changes in 500 ms via the notifier; count 'state' events ≤ 2 + final */ });
```
(`startMonitoringService` and the method channels fail silently in tests — they are wrapped in try/catch already.)

- [ ] **Step 6: Run to verify failure.** — `flutter test test/session_engine_host_test.dart` → FAIL.

- [ ] **Step 7: Implement `SessionEngineHost`** — queue commands received before `start()` completed; `handleCommand` maps `cmd` to the notifier methods listed in Interfaces; `testAction` runs `dispatcher.runSingle(id, event(source:'test'))` and emits `actionStatus`; `sync` re-sends the current state.

- [ ] **Step 8: Run to verify pass.**

- [ ] **Step 9: Write the failing mirror test**

```dart
test('mirror applies state events and tracks heartbeat', () async {
  final c = ProviderContainer(); final n = c.read(sessionMirrorProvider.notifier);
  n.debugReceive(ServiceEvent.state(const ActiveSessionState(isRunning: true, currentBpm: 61)).toMessage());
  expect(c.read(sessionMirrorProvider).currentBpm, 61);
  n.debugReceive(ServiceEvent.heartbeat(DateTime.now()).toMessage());
  expect(n.serviceAlive, isTrue);
});
test('selectMode without a running service updates settings and local state only', () { /* no sendDataToTask call; settings.preferredMode changed */ });
```

- [ ] **Step 10: Run to verify failure.** — `flutter test test/session_mirror_provider_test.dart` → FAIL.
- [ ] **Step 11: Implement `SessionMirrorNotifier`** — registers `FlutterForegroundTask.addTaskDataCallback(_receive)` in `build()`; `debugReceive` is `@visibleForTesting` and calls `_receive`; on `ready` flushes the pending command; `build()` also runs the quick-tile cold-start check (`consumeQuickTileLaunchTrigger` → `startSession()`), moved from the notifier.
- [ ] **Step 12: Run to verify pass.**

- [ ] **Step 13: Host the engine in the TaskHandler**

In `foreground_task_service.dart`: `SleepStopTaskHandler` owns a `SessionEngineHost? _host`; `onStart(developer)` → `_host = SessionEngineHost(send: FlutterForegroundTask.sendDataToMain)..start()`; `onReceiveData(data)` → `SessionCommand.fromMessage(data)?.let(_host!.handleCommand)`; `onRepeatEvent` → `sendDataToMain(ServiceEvent.heartbeat(now).toMessage())`; `onNotificationButtonPressed` → `_host!.handleCommand(SessionCommand.stop() / stillAwake())`; `onDestroy` → `_host?.dispose()`. `onStart(system)` keeps today's interruption behaviour until Task 4. Remove `addTaskDataCallback(_onForegroundTaskData)` and the `startMonitoringService` calls from `SleepSessionNotifier.build()`/`startSession` (the host/mirror own the service lifecycle; the notifier still calls `updateNotification` and `stopMonitoringService`).

- [ ] **Step 14: Swap the UI to the mirror**

`dashboard_tab.dart:36-39`, `settings_screen.dart:35,98`: `sleepSessionProvider` → `sessionMirrorProvider` (same method names). `home_screen.dart`: keep `ref.read(sleepActionDispatcherProvider)` (UI-side test runs) and add `ref.read(sessionMirrorProvider)`. Dashboard status badge: when `session.isRunning && !mirror.serviceAlive` show `s.serviceInactive` (new string FR/NL/DE/ES: « Service inactif », « Service inactief », « Dienst inaktiv », « Servicio inactivo »).

- [ ] **Step 15: Verify**

Run: `flutter analyze && flutter test` → clean, all green (56 + new). Device: start a simulated watch session, swipe SleepStop away from recents, wait 2 min: `adb shell dumpsys notification --noredact | grep -A2 sleepstop` shows a changing BPM title; reopen the app → dashboard shows the running session; `Tester le fondu` → veil → tap → resumed. `adb shell dumpsys activity services com.sleepstop.sleep_stop` shows the service alive.

- [ ] **Step 16: Commit** — `git commit -m "feat(engine): sleep engine hosted in the foreground service isolate, UI as live mirror"`.

---

### Task 4: Persisted snapshot and resume after a kill

**Files:**
- Create: `lib/models/active_session_snapshot.dart`, `lib/services/snapshot_store.dart`
- Modify: `lib/providers/sleep_session_provider.dart` (`exportSnapshot()`, `resumeFrom()`), `lib/service/session_engine_host.dart` (`startResumed(snapshot)`, periodic write), `lib/services/foreground_task_service.dart` (`onStart(system)` decision), `lib/l10n/app_strings.dart` (resumed notification + history line), `packages/sleepstop_native/.../MediaControlHandler.kt` + new `SessionWatchdogReceiver.kt` (watchdog alarm)
- Test: `test/active_session_snapshot_test.dart`, `test/resume_decision_test.dart`, `test/session_engine_host_test.dart` (+1)

**Interfaces:**
- Produces: `class ActiveSessionSnapshot { startedAt, mode, simulated, watchId, watchName, baselineBpm, thresholdPenaltyBpm, stillAwakeCount, trialNightConsumed, lastWrittenAt, bpmTimeline; toJson/fromJson }`; `class SnapshotStore { Future<void> write(ActiveSessionSnapshot); Future<ActiveSessionSnapshot?> read(); Future<void> clear(); }` (key `sleepstop_active_session_v1`); `enum ResumeDecision { resume, interrupted, nothing }` and `ResumeDecision decideResume(ActiveSessionSnapshot? snap, DateTime now)` (pure); notifier `ActiveSessionSnapshot? exportSnapshot()`, `Future<void> resumeFrom(ActiveSessionSnapshot)`.
- Native: `scheduleWatchdog(seconds)` / `cancelWatchdog()` on `com.sleepstop/media_control`; `SessionWatchdogReceiver.onReceive` → if `!ForegroundService.isRunningServiceState.value` then `ForegroundServiceManager().restart(context)` (same call as the plugin's own `RestartReceiver`; confirm the constructor at implementation).

- [ ] **Step 1: Write the failing tests**

```dart
test('snapshot round-trips', () { /* all fields, timeline capped at 600 */ });
test('stale snapshot is not resumed', () {
  final old = snap(lastWrittenAt: now.subtract(const Duration(hours: 9)));
  expect(decideResume(old, now), ResumeDecision.interrupted);
  expect(decideResume(null, now), ResumeDecision.nothing);
  expect(decideResume(snap(lastWrittenAt: now.subtract(const Duration(minutes: 3))), now), ResumeDecision.resume);
});
test('resume decision without a UI', () async { /* host.startResumed(snap) sends 'resumed' then 'state' with isRunning true and phase monitoring, no sendDataToMain before start */ });
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement snapshot model, store and `decideResume`** (8 h threshold from Global Constraints).
- [ ] **Step 4: Implement `exportSnapshot` / `resumeFrom` in the notifier** — `resumeFrom`: state `monitoring`, `sessionStartTime = snap.startedAt`, `_nightThresholdPenaltyBpm`, `_stillAwakeCount`, timeline restored, baseline restored (calibrator marked complete with that baseline) or a fresh 60 s calibrator when null; watch mode → `scanAndConnect(preferredDeviceId: snap.watchId, timeout: 15 s)`; phone mode → countdown reset to the configured interval; the trial night is not consumed twice (`trialNightConsumed`). `_finalizeNight`, `stopSession`, `_abortForSignalLoss` call `SnapshotStore.clear()`.
- [ ] **Step 5: Host writes the snapshot** — in `onRepeatEvent` every 6th tick (30 s) while `state.isRunning`, and immediately after `start`/`stillAwake`; `onStart(system)` → `decideResume(await store.read(), now)`: `resume` → `startResumed` + notification `s.fgResumedTitle(hh:mm)` / `s.fgResumedBody`; `interrupted` → today's interruption notification + `stopService`; `nothing` → `stopService`.
- [ ] **Step 6: Watchdog alarm** — `startSession` (host) calls `scheduleWatchdog(45)` and re-arms it every 30 s tick; `_finalizeNight`/`stopSession`/`_abortForSignalLoss` call `cancelWatchdog()`. Kotlin uses `AlarmManager.setExactAndAllowWhileIdle` when `canScheduleExactAlarms`, else `setAndAllowWhileIdle`; receiver registered in the plugin manifest.
- [ ] **Step 7: Run to verify pass** — `flutter analyze && flutter test`.
- [ ] **Step 8: Device verification** — simulated session, `adb shell run-as com.sleepstop.sleep_stop kill -9 $(adb shell pidof com.sleepstop.sleep_stop)`: within 60 s the notification reads « Veille reprise… », `dumpsys activity services` shows the service, reopening the app shows `monitoring` with the original start time.
- [ ] **Step 9: Commit** — `git commit -m "feat(engine): persisted session snapshot, resume after process kill, watchdog alarm"`.

---

### Task 5: Kill detection, targeted help, Samsung row, heartbeat banner

**Files:**
- Create: `lib/services/kill_detector.dart`, `lib/ui/widgets/interruption_banner.dart`
- Modify: `packages/sleepstop_native/.../MediaControlHandler.kt` (`getRecentExitReasons`, `deviceInfo`, `openBatterySettings`), `lib/services/media_control_service.dart` (same three), `lib/ui/dashboard_tab.dart` (banner under the Pro banner), `lib/ui/settings_screen.dart` (Samsung row under « À l'endormissement »), `lib/models/sleep_settings.dart` (`lastInterruptionAt`, `interruptionAcknowledged`), `lib/l10n/app_strings.dart`
- Test: `test/kill_detector_test.dart`

**Interfaces:**
- Produces: `class ExitRecord { DateTime at; String reason; String? description; }`; `List<ExitRecord> relevantKills(List<ExitRecord> exits, ActiveSessionSnapshot? lastNight)` (pure: keeps `SIGNALED`, `LOW_MEMORY`, `OTHER` whose `at` is between `lastNight.startedAt` and `lastNight.lastWrittenAt + 8 h`); `Future<void> KillDetector.checkOnLaunch(ref)` stores `lastInterruptionAt` in settings when a new kill is found.
- Native: `getRecentExitReasons()` → `List<Map>` from `ActivityManager.getHistoricalProcessExitReasons(packageName, 0, 10)` with `reason` mapped to the `ApplicationExitInfo.REASON_*` constant name (API < 30 → empty list); `deviceInfo()` → `{manufacturer, model, sdkInt}`; `openBatterySettings()` → `com.samsung.android.sm.ACTION_BATTERY`, fallback `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`.

- [ ] **Step 1: Write the failing test**

```dart
test('only SIGNALED/LOW_MEMORY/OTHER during a session count', () {
  final night = snap(startedAt: t(22, 0), lastWrittenAt: t(23, 30));
  final exits = [ExitRecord(at: t(22, 22), reason: 'SIGNALED'), ExitRecord(at: t(19, 59), reason: 'USER_REQUESTED'),
                 ExitRecord(at: t(22, 40), reason: 'CRASH'), ExitRecord(at: t(9, 0), reason: 'LOW_MEMORY')];
  expect(relevantKills(exits, night).map((e) => e.reason), ['SIGNALED']);
  expect(relevantKills(exits, null), isEmpty);
});
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement native methods, Dart wrappers, `relevantKills`, `KillDetector.checkOnLaunch`** (called from `HomeScreen.initState` after the mirror).
- [ ] **Step 4: Banner and Samsung row** — `InterruptionBanner` shown when `settings.lastInterruptionAt != null && !interruptionAcknowledged`: text `s.interruptionBanner(hh:mm)`; buttons « Compris » (acknowledge) and, if `manufacturer == 'samsung'`, « Empêcher la mise en veille » → `openBatterySettings()`. Settings row (Samsung only): `s.samsungNeverSleepTitle` → `openBatterySettings()`. Strings in FR/NL/DE/ES.
- [ ] **Step 5: Run to verify pass** — `flutter analyze && flutter test`.
- [ ] **Step 6: Commit** — `git commit -m "feat(resilience): detect process kills during a night, targeted Samsung help, heartbeat banner"`.

---

### Task 6: Release 1.1.0+4 and documentation

**Files:**
- Modify: `pubspec.yaml` (`version: 1.1.0+4`), `lib/app_info.dart` (`'1.1.0 (4)'`), `RELEASE_CHECKLIST.md` (level 2 shipped; manual tests), `specs/2026-10-19-service-isolate-engine-design.md` (status: implemented), `README.md` (architecture diagram: engine in the service)

- [ ] **Step 1: Bump versions and update docs.**
- [ ] **Step 2: Build** — `flutter build appbundle --release` → `versionCode="4"` in `build/app/intermediates/merged_manifest/release/*/AndroidManifest.xml`; `flutter build apk --release` for sideload testing.
- [ ] **Step 3: Full device validation** — the five manual tests of the spec's last section, on the **release** APK; record results in `RELEASE_CHECKLIST.md`.
- [ ] **Step 4: Commit** — `git commit -m "chore(release): 1.1.0+4 — service-hosted engine"`.
