# Module « Quand je m'endors » — exploration et plan

Date : 18 octobre 2026 · Base : `main` @ `85bf6fc` · Statut : **plan en attente de validation, aucun code écrit**

---

## Étape 0 — Exploration du dépôt

### Stack
| Sujet | État actuel |
|---|---|
| Framework | Flutter 3.41.9 (Dart 3.11.5), UI 100 % Dart, couche native Kotlin pour média / BLE / tuile / voile noir |
| Android | minSdk 26, targetSdk 36, compileSdk 36, AGP 8.11.1, **Kotlin 2.2.20**, Gradle 8.14, Java 17, desugaring activé |
| Gestion d'état | Riverpod 3 (`Notifier` / `NotifierProvider`), un provider par domaine : `settingsProvider`, `sleepSessionProvider`, `sessionLogsProvider`, `billingProvider` |
| Persistance | `SharedPreferences` : un seul JSON `sleepstop_settings_v1` (modèle immuable `SleepSettings` avec `copyWith` / `toJson` / `fromJson`), un JSON pour l'historique. **Aucun stockage chiffré** aujourd'hui (pas de Keystore, pas de `flutter_secure_storage`) |
| Réseau | `dart:io HttpClient` brut (télémétrie Firestore REST, codes VIP). Pas de `package:http`, pas de `crypto` |
| Dépendances natives | aucune lib Android ajoutée à la main ; `play-services` uniquement via les plugins Flutter (billing) |

### Où naît l'événement « endormissement » et qui le consomme
Tout vit dans `lib/providers/sleep_session_provider.dart` (`SleepSessionNotifier`) :

1. **Détection** : mode montre → ticker 1 s évalue `SleepCriteria` ; mode téléphone → fondu de 60 s sans secousse.
2. **Coupure audio** : `_triggerWatchSleepDetected` / `_startPhone60sFadeSequence` → fondu du volume → `pauseAndRestoreVolumeAfterDelay` (pause MediaSession + touche MEDIA_PAUSE). C'est la « coupure audio existante ».
3. **Fenêtre de grâce 90 s** (`_enterGraceWindow`) : voile noir, bouton « Encore réveillé » (dashboard, notification, secousse, toucher du voile). `stillAwake()` relance la lecture et annule tout.
4. **Confirmation** : `_finalizeNight()` = **le seul endroit où la nuit est tenue pour acquise** : fermeture des apps, journal, apprentissage, télémétrie, état `pausedCompleted`.

Il n'y a pas de bus d'événements : les étapes sont des appels directs dans le notifier. Pour le module, le point d'accroche naturel est `_finalizeNight()` (voir § Décision 1).

### Service d'arrière-plan
- `flutter_foreground_task` 10.0 : `ForegroundService` natif déclaré `connectedDevice|specialUse`, notification persistante, `WakeLock` CPU autorisé, isolate Dart « task handler » qui ne fait qu'un heartbeat toutes les 5 s et relaie les boutons de notification.
- **Toute la logique tourne dans l'isolate principal** (le `SleepSessionNotifier`), maintenu vivant par le service. Écran éteint : OK tant que le service tourne ; l'exemption batterie est demandée au premier démarrage.
- Pas de WorkManager, pas d'AlarmManager.

### Réglages
- Une page unique `lib/ui/settings_screen.dart` (`SettingsScreen`), 5 sections rendues par un composant `_Section` (titre + carte) et des briques `_Toggle`, `_LinkRow`, `_SliderRow`, `_RadioRow`. Feuilles secondaires en `showModalBottomSheet` (apps cibles, guide montre, RGPD, Pro).
- Thème OLED : `OledColors` (noir pur, ambre, indigo, teal, or Pro), textes via `AppStrings` (FR/NL/DE/ES, méthode `tr(fr:, nl:, de:, es:)`).

### Ce que dit la doc officielle Google Home APIs (vérifié le 18/10/2026)
Sources : [Get started](https://developers.home.google.com/apis/android/get-started), [Release notes](https://developers.home.google.com/apis/android/release-notes), [OAuth](https://developers.home.google.com/apis/android/oauth), [Initialize](https://developers.home.google.com/apis/android/initialize), [Permissions](https://developers.home.google.com/apis/android/permissions), [Devices](https://developers.home.google.com/apis/android/device), [Control](https://developers.home.google.com/apis/android/device/control), [LevelControl ref](https://developers.home.google.com/reference/kotlin/com/google/home/matter/standard/LevelControl).

| Point | Doc | Écart avec le brief |
|---|---|---|
| Distribution du SDK | **Pas sur Maven.** « Les Home APIs ne font pas encore partie des bibliothèques standard » : on télécharge `home.android.sdk_GHP_1_11` (bucket Cloud Storage, connecté à Google Home Developers) et on héberge les AAR localement (`play-services-home-*.aar`, `play-services-home-types-*.aar`). | Le brief parle d'« une dépendance » : ce sera un dossier `android/app/libs/` avec les AAR + `flatDir`. À décider : commit des binaires dans le dépôt (public !) ou téléchargement à la main par le dev (README). |
| Version | GA **1.11** (23/09/2026). Play services ≥ **26.36.25**. | — |
| Kotlin | **Kotlin 2.4.0 requis** depuis 1.11, sinon `-Xskip-metadata-version-check`. `kotlinx.coroutines` à importer explicitement sinon erreur bloquante au runtime. | Le projet est en Kotlin 2.2.20. Passage à 2.4.0 = risque de compat avec le plugin Gradle de Flutter 3.41 ; repli = garder 2.2.20 + le flag. À tester en premier (spike de 30 min). |
| minSdk | Non précisé. Appareil de test : **Android 10+**. | SleepStop minSdk 26 : on garde 26 et on **gate le module en runtime sur API ≥ 29 + Play services disponibles**. |
| Init | `Home.getClient(context, HomeConfig(coroutineContext = Dispatchers.IO, factoryRegistry = FactoryRegistry(traits = [OnOff, LevelControl], types = [OnOffLightDevice, DimmableLightDevice, …])))`, **singleton**, contexte application « depuis une Activity ou un Service ». | Conforme : singleton Kotlin `HomeClientHolder`. |
| Permissions | `homeManager.registerActivityResultCallerForPermissions(activity)` dans `onCreate` ; `hasPermissions(): Flow<PermissionsState>` ; `requestPermissions()` ouvre l'UI Google ; **une seule structure à la fois** ; « vérifier à chaque démarrage que les permissions sont toujours en vigueur », sinon purger le cache. Révocation via Google Home app ou Mon compte Google. | Conforme au brief (vérification au démarrage + désactivation + statut dans l'écran). La demande nécessite une Activity : déclenchée depuis l'écran de réglages uniquement. |
| OAuth / Console | Projet Google Cloud, écran de consentement **Externe** avec utilisateurs test, client OAuth **Android** (package + SHA-1 de la clé debug ET de la clé de signature Play). **« Le Google Home Developer Console n'est pas encore disponible pour l'enregistrement »** ; sans enregistrement : max **100 utilisateurs test**, et « une inscription approuvée reste nécessaire pour publier ». | **Bloquant externe** : l'action lumières ne pourra être livrée au grand public qu'une fois l'enregistrement ouvert et approuvé. Elle peut être livrée à 100 testeurs. |
| Lecture | `home.structures()`, `structure.rooms()`, `home.devices()` sont des `Flow` ; `.list()` renvoie le premier `Set` ; filtre `devices.filter { it.has(OnOff) }` ; type via `device.type(DimmableLightDevice).map { it.standardTraits.levelControl }` ; état réseau `device.metadata.sourceConnectivity.connectivityState` (`ONLINE` / `PARTIALLY_ONLINE` / `OFFLINE`). | — |
| Commandes | `onOffTrait.off()` ; `levelControlTrait.moveToLevel(level: UByte 0–254, transitionTime, optionsMask, optionsOverride)` ; `moveToLevelWithOnOff(...)` existe dans la référence et « éteint quand le niveau final atteint minLevel ». **Unité de `transitionTime` non documentée dans le guide** (spec Matter : dixièmes de seconde). | À vérifier sur le SDK téléchargé (type Kotlin exact) avant d'implémenter la transition native ; repli = paliers. |
| Arrière-plan | **Rien dans la doc** sur l'exécution depuis un service de premier plan ou écran éteint. Les commandes sont des `suspend` qui « ne se terminent que lorsque l'API répond ». | Hypothèse : fonctionne tant que le process vit (notre FGS). Point n° 1 de la checklist manuelle. Timeout 10 s obligatoire. |

---

## Décisions d'architecture proposées

### Décision 1 — Point de déclenchement : `_finalizeNight()`, pas la pause
Le brief dit « au même moment que la coupure audio ». Dans SleepStop, la coupure audio est suivie d'une fenêtre de 90 s « Encore réveillé » conçue pour absorber les faux positifs. Déclencher les actions **à la fin de cette fenêtre** (= `_finalizeNight`) évite d'éteindre les lumières puis de devoir les rallumer à chaque faux positif, et garantit l'ordre « audio d'abord ». Le fondu lumineux réglable (30 s à 2 min) et la notification « Annuler » restent en place pour la seconde chance.
Alternative si tu préfères l'extinction dès la pause : même code, l'événement est émis dans `_enterGraceWindow` et `stillAwake()` appelle `dispatcher.cancelAll()`. Un drapeau, pas une refonte. **À trancher.**

### Décision 2 — Bus d'événements Dart minimal
Nouveau `lib/sleep_actions/sleep_event_bus.dart` : `SleepDetectedEvent(timestamp, mode, source)` publié sur un `StreamController.broadcast` exposé par `sleepEventBusProvider`. `_finalizeNight` émet **une ligne** (`ref.read(sleepEventBusProvider).emit(...)`) après la coupure audio et la journalisation : si le bus ou un abonné explose, c'est hors du chemin critique (emit est synchrone, ne jette pas, les abonnés tournent dans leurs propres futures).
La coupure audio **n'est pas** refactorée en `SleepAction` : elle a sa propre machine à états (fondu, grâce, reprise) ; la transformer n'est ni trivial ni sans risque.

### Décision 3 — Actions en Dart, logique Google Home en Kotlin
```
lib/sleep_actions/
  sleep_action.dart            abstract class SleepAction { String id; bool isEnabled(SleepSettings); Future<void> execute(SleepActionContext); Future<void> cancel(); }
  sleep_action_dispatcher.dart  s'abonne au bus ; pour chaque action activée : Future.wait non-bloquant, timeout 10 s, try/catch, statut par action (SleepActionStatus) persisté pour l'écran
  sleep_action_status.dart      enum + dernier message + horodatage, par action
  actions/lights_off_action.dart        → MethodChannel "com.sleepstop/home_actions"
  actions/broadcast_intent_action.dart  → MethodChannel (sendBroadcast côté Kotlin)
  actions/webhook_action.dart           → dart:io HttpClient, HMAC via package:crypto, secret via flutter_secure_storage
android/app/src/main/kotlin/com/sleepstop/sleep_stop/homeactions/
  HomeActionsChannel.kt     méthodes : checkAvailability, requestPermissions, listLights, executeLightsOff, cancelAndRestore, sendSleepBroadcast
  HomeClientHolder.kt       singleton Home.getClient + FactoryRegistry(OnOff, LevelControl, OnOffLightDevice, DimmableLightDevice, ColorTemperatureLightDevice, ExtendedColorLightDevice)
  LightsFadeController.kt   mémorise l'état initial (onOff + currentLevel), fondu natif (moveToLevelWithOnOff + transitionTime) si LevelControl, sinon paliers toutes les 2 s, puis off() ; cancel() restaure ; notification « Annuler » (canal dédié, bouton → BroadcastReceiver → cancel)
```
Le `MainActivity` ne fait que `registerActivityResultCallerForPermissions(this)` dans `onCreate` et route la méthode `requestPermissions` (obligation Activity).

### Décision 4 — Réglages
Extension de `SleepSettings` (même JSON, rétro-compatible, défauts = tout désactivé) :
```
sleepActions: {
  enabled: false,
  lights:  { enabled: false, deviceIds: [], roomIds: [], fadeSeconds: 30 },
  intent:  { enabled: false },
  webhook: { enabled: false, url: "", hasSecret: false }
}
```
Le secret HMAC n'est **jamais** dans ce JSON : `flutter_secure_storage` (Android Keystore + EncryptedSharedPreferences côté plugin), clé `sleepstop_webhook_secret`.

### Décision 5 — Écran « Quand je m'endors »
`lib/ui/sleep_actions_screen.dart`, ouvert depuis `SettingsScreen` → section **À l'endormissement** → ligne « Quand je m'endors » (avec résumé : « 2 actions actives »). Même briques (`_Section`, `_Toggle`, `_LinkRow`) extraites dans `lib/ui/widgets/settings_blocks.dart` pour être partagées. Contenu :
- toggle principal ;
- **Lumières** : toggle, statut (Non disponible / Non connecté / Connecté à « Maison » / Permission révoquée / Hors ligne), bouton « Connecter Google Home », liste pièces → appareils (cases à cocher, pièce entière = tous ses appareils), durée du fondu (Instantané / 30 s / 1 min / 2 min), « Tester maintenant » (avec « Annuler » dans la notification) ;
- **Intent** : toggle, nom exact `com.sleepstop.sleep_stop.SLEEP_DETECTED` avec bouton copier, extra `timestamp` (epoch ms) documenté, « Tester maintenant » ;
- **Webhook** : toggle, champ URL (refus de `http://` avec message), champ secret (masqué, « Enregistré » si présent, bouton effacer), « Tester maintenant » qui affiche le code HTTP.
Aucune popup la nuit : les erreurs d'exécution ne font que mettre à jour le statut et un `debugPrint` (release : pas d'URL, pas d'identifiant d'appareil, pas de secret dans les logs).

### Décision 6 — Gating runtime du module lumières
`checkAvailability` renvoie `unsupportedAndroid` (< API 29), `playServicesMissing` / `playServicesOutdated` (`GoogleApiAvailability` et version < 26.36.25), `sdkError`, ou `available`. L'écran affiche la raison ; l'action est désactivée automatiquement si indisponible ou si `hasPermissions()` ≠ GRANTED au démarrage.

---

## Dépendances à ajouter (validation demandée)
| Dépendance | Pourquoi | Remarque |
|---|---|---|
| AAR Home APIs 1.11 (`play-services-home`, `play-services-home-types`) dans `android/app/libs/` | Action lumières | Binaires Google, pas sur Maven. Dépôt public → je propose de **ne pas les committer** : `android/app/libs/.gitignore` + un `README` qui explique le téléchargement. Dis-moi si tu préfères les committer. |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` (version alignée sur le SDK, à lire dans son `README`) | Exigé par le SDK 1.11 | Gradle |
| Kotlin Gradle plugin 2.2.20 → 2.4.0 **ou** flag `-Xskip-metadata-version-check` | Exigé par le SDK 1.11 | Spike de compat Flutter en tout premier ; je te dis lequel passe |
| `crypto` (pub.dev, Dart team) | HMAC-SHA256 du webhook | Pur Dart, pas de code natif |
| `flutter_secure_storage` | Secret webhook chiffré (Keystore) | Plugin natif ; alternative : implémenter AES-GCM/Keystore nous-mêmes en Kotlin (plus de code, zéro dépendance). Ton choix. |

Pas de `permission_handler`, pas de `http`, pas de WorkManager.

---

## Plan d'implémentation par étapes commitables

### Étape 1 — Socle (dispatcher) · ~0,5 j
Fichiers : `lib/sleep_actions/{sleep_event_bus,sleep_action,sleep_action_dispatcher,sleep_action_status}.dart`, `lib/models/sleep_settings.dart` (+ `sleepActions`), `lib/providers/settings_provider.dart` (setters), `lib/providers/sleep_session_provider.dart` (**1 ligne** dans `_finalizeNight`), `lib/ui/widgets/settings_blocks.dart` (extraction), `lib/ui/settings_screen.dart` (ligne d'entrée), `lib/ui/sleep_actions_screen.dart` (toggle principal + 3 sections vides avec statut « Bientôt »), `lib/l10n/app_strings.dart`.
Tests : `test/sleep_action_dispatcher_test.dart` avec `FakeSleepAction` (exécution parallèle mesurée, une action qui jette n'empêche pas les autres, timeout 10 s via `fakeAsync`, toggles respectés, master off = rien). Vérif : `flutter test` existant inchangé, un faux positif + « Encore réveillé » ne déclenche rien.

### Étape 2 — Action Intent · ~0,25 j
`actions/broadcast_intent_action.dart`, `HomeActionsChannel.kt` (`sendSleepBroadcast`), écran (section intent complète). Valide le pipeline bout en bout sur l'appareil avant d'attaquer Google Home. Test manuel avec `adb shell am monitor` / Tasker.

### Étape 3 — Action Webhook · ~0,5 j
`actions/webhook_action.dart` (client injectable pour les tests), `WebhookSecretStore` (secure storage), écran. Tests : signature HMAC connue (vecteur de test), refus de `http://`, payload exact, 1 retry max, timeout.

### Étape 4 — Action Lumières · ~2 j + attente setup externe
4a. Spike compat : AAR 1.11 + Kotlin (2.4.0 ou flag) + coroutines dans une branche ; `flutter build apk` doit passer. Je te rends compte avant la suite.
4b. `HomeClientHolder`, `checkAvailability`, `requestPermissions` (MainActivity), `listLights` (structures → pièces → appareils avec `has(OnOff)`, `connectivityState`, type).
4c. `LightsFadeController` : snapshot, fondu natif ou paliers, `off()`, notification « Annuler », `cancelAndRestore`.
4d. Écran : connexion, sélection pièces/appareils, durée, statut, test, révocation.
4e. Tests Kotlin unitaires du calcul de paliers ; Dart : `LightsOffAction` avec faux channel.
Configuration de ton côté avant 4b : projet Google Cloud, consentement Externe + ton compte en testeur, client OAuth Android avec `com.sleepstop.sleep_stop` + SHA-1 **debug**, **upload** et **Play App Signing** ; télécharger le SDK 1.11.

### Étape 5 — Finitions
Checklist manuelle, résumé des fichiers, mise à jour de `RELEASE_CHECKLIST.md` (déclarations Play Console : rien de nouveau pour intent/webhook ; lumières = OAuth Google verifié + Developer Console quand ouvert).

Ordre proposé : **1 → 2 → 3 → 4**. Le brief demande « dispatcher puis lumières » ; je propose d'intercaler intent et webhook (petits, sans dépendance externe) pour valider le pipeline pendant que tu fais le setup Google Cloud et que le spike Kotlin tourne. Dis-moi si tu tiens à l'ordre du brief.

---

## Checklist de test manuel (à exécuter en fin de tâche)
1. Nuit réelle écran éteint, mode montre : lumières éteintes à la fin des 90 s, pas avant.
2. Mode Doze (adb `dumpsys deviceidle force-idle`) pendant la grâce : l'action part quand même (FGS).
3. Wi-Fi coupé : statut « Hors ligne / pas de réseau » dans l'écran, aucune popup, audio coupé normalement.
4. Permissions Google Home révoquées depuis l'app Google Home : au prochain lancement, action lumières désactivée + statut « Permission révoquée ».
5. « Annuler » dans la notification pendant le fondu : lumières restaurées à l'état initial (on + niveau).
6. « Encore réveillé » pendant la grâce : aucune action lancée (Décision 1).
7. Appareil hors ligne dans la sélection : les autres s'éteignent, statut partiel.
8. Intent reçu par Tasker avec `timestamp`.
9. Webhook : Home Assistant reçoit le POST, signature valide ; URL `http://` refusée à la saisie.
10. Build release : aucun log contenant URL, id d'appareil ou secret (`adb logcat` filtré).
