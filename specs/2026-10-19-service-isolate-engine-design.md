# Niveau 2 — Moteur de veille dans le service de premier plan

Date : 19 octobre 2026 · Base : `main` @ `752aabd` · Statut : **spec à valider avant tout code**

## Problème
La logique de détection (`SleepSessionNotifier` et ses services) tourne dans l'isolate principal de Flutter, créé et détruit avec `MainActivity`. Deux cas réels observés sur le Galaxy Fold :
- fermeture de l'app (balayage des récents) → activité détruite → moteur Flutter détruit → détection morte, service natif toujours là avec une notification figée ;
- **SIGKILL du processus par la gestion d'énergie Samsung à 22:22:48** (13 s après le lancement de la veille, malgré l'exemption batterie Android) → service collant relancé à 00:00 dans un nouveau processus, sans logique.

Le correctif provisoire (commit `df2ee2e`) rend la notification honnête après un redémarrage. Il ne restaure pas la veille.

## Objectif
Une veille lancée à 22:00 doit survivre à : la fermeture de l'app, l'écran éteint, le mode Doze, un kill du processus suivi d'un redémarrage du service. L'interface doit refléter l'état réel à tout moment, y compris après réouverture au milieu de la nuit.

## Architecture cible

### A. Le moteur tourne dans l'isolate du service
`flutter_foreground_task` démarre le service natif avec son propre moteur Flutter et appelle `startSleepStopForegroundCallback` → `SleepStopTaskHandler.onStart`. C'est là que vit désormais le moteur :
- `onStart` crée un `ProviderContainer` Riverpod (sans widget) et instancie `sleepSessionProvider`, `settingsProvider`, `sessionLogsProvider`, `sleepEventBusProvider`, `sleepActionDispatcherProvider`. Tout le code existant est réutilisé tel quel : il ne dépend d'aucun widget.
- `onRepeatEvent` (toutes les 5 s) sert de battement de cœur et de garde-fou (voir D).
- `onDestroy` persiste le snapshot (voir C) et libère BLE/capteurs.
- Les plugins utilisés par le moteur (`flutter_blue_plus`, `sensors_plus`, `shared_preferences`, `flutter_local_notifications`, `flutter_secure_storage`) sont enregistrés automatiquement sur le moteur du service par le registrant généré.

### B. L'interface est un miroir
- `SessionMirror` : le service sérialise `ActiveSessionState` en JSON compact à chaque changement (au plus 2 fois par seconde, la courbe BPM envoyée seulement quand un point est ajouté) via `FlutterForegroundTask.sendDataToMain`.
- Côté UI, `sessionMirrorProvider` (`Notifier<ActiveSessionState>`) reconstruit l'état depuis le JSON. `DashboardTab`, `HistoryTab` et `SleepActionsScreen` passent de `sleepSessionProvider` à `sessionMirrorProvider` ; aucune logique ne change dans les widgets.
- Commandes UI → service via `FlutterForegroundTask.sendDataToTask` : `start(mode, simulate)`, `stop`, `stillAwake`, `selectMode`, `testFade`, `manualWake`, `testAction(id)`. Le service répond par un nouvel état.
- Démarrage d'une veille depuis l'UI : l'UI démarre le service (`startService`) puis envoie `start`. Depuis la tuile ou la notification : inchangé, le service reçoit la commande directement.
- Au lancement de l'app, si le service tourne, l'UI demande `sync` et reçoit l'état courant : réouverture à 3 h du matin = dashboard vivant.

### C. Veille persistée et reprise après kill
- `ActiveSessionSnapshot` (JSON dans `SharedPreferences`, clé `sleepstop_active_session_v1`) : `startedAt`, `mode`, `simulated`, `watchId`, `watchName`, `baselineBpm`, `thresholdPenaltyBpm`, `stillAwakeCount`, `trialNightConsumed`, `lastWrittenAt`, `bpmTimeline` (≤ 600 points). Écrit au démarrage, puis toutes les 30 s et à chaque événement clé ; effacé à la fin normale (stop, nuit journalisée, abandon).
- `onStart(starter == TaskStarter.system)` : si un snapshot existe et date de moins de 8 h → **reprise** : notification « Veille reprise après une interruption à HH:MM », reconnexion directe à la montre sauvegardée (pas de scan complet), recalibration courte (60 s) si la référence est absente, reprise des compteurs, même `startedAt` pour le journal du matin. Si aucun snapshot ou trop vieux → notification « Surveillance interrompue » (comportement actuel) et arrêt.
- Le mode téléphone reprend son compte à rebours à l'intervalle configuré.

### D. Garde-fou et Samsung
- Le battement de cœur du service écrit `lastHeartbeatAt` ; l'UI affiche « Service inactif » si l'horodatage a plus de 20 s alors qu'une veille est censée tourner.
- Détection `Build.MANUFACTURER == samsung` : ligne dans l'écran de permissions, l'onboarding et Réglages → « Samsung : ne jamais mettre SleepStop en veille » ouvrant `Paramètres → Batterie → Applications jamais mises en veille` (intent `com.samsung.android.sm.ACTION_BATTERY` avec repli vers les réglages batterie génériques). Après une nuit interrompue, bannière sur le dashboard le lendemain.

### E. Ponts natifs accessibles depuis les deux moteurs
Aujourd'hui les `MethodChannel` (volume, pause, reprise, voile, tuile, broadcast, Google Home) sont enregistrés dans `MainActivity.configureFlutterEngine`, donc seulement sur le moteur de l'activité. Le moteur du service n'y a pas accès.
- Création d'un **plugin local** `packages/sleepstop_native/` (dépendance `path:` dans `pubspec.yaml`, `FlutterPlugin` + `ActivityAware` en Kotlin) : enregistré automatiquement sur chaque moteur par le registrant généré, contexte application pour tout ce qui n'a pas besoin d'activité. `MainActivity` ne garde que : demandes de permissions runtime, ajout de la tuile, `bindActivity` Google Home, tuile → commande.
- Le code Kotlin existant (`MainActivity` média/volume/apps, `NightOverlay`, `HomeActionsChannel`, `LightsController`, source sets Home APIs) déménage dans le plugin sans changement de logique.

### F. Ce qui ne change pas
Algorithme de détection, fenêtre de grâce, voile noir, module « Quand je m'endors » (bus, dispatcher, actions), écrans, textes, tests existants (ils restent verts : la logique n'est pas modifiée, seul son hôte change).

## Risques et parades
| Risque | Parade |
|---|---|
| `flutter_blue_plus` dans un isolate de service | Plugin sans dépendance d'activité pour scan/connexion ; test réel montre + fallback : si l'initialisation BLE échoue dans le service, erreur explicite dans l'UI. |
| Deux moteurs Flutter = mémoire ×2 (~+60 Mo) | Acceptable ; le moteur UI est libéré à la fermeture de l'app, seul celui du service reste la nuit. |
| Ordre de démarrage service/commande | `sendDataToTask` attend `onStart` ; file d'attente d'une commande côté UI jusqu'au premier état reçu. |
| Snapshot incohérent après kill en plein fondu | Reprise toujours en phase `monitoring` (jamais en fondu ni en grâce) ; le média n'est pas touché à la reprise. |
| Samsung tue aussi le service relancé | Hors de notre contrôle ; mitigation = réglage « jamais en veille » + notification honnête. |

## Plan de livraison (4 commits)
1. **Plugin natif** `packages/sleepstop_native` : déplacement du Kotlin, canal unique, `MainActivity` allégée. Build + test UI identiques (aucun changement visible).
2. **Moteur dans le service + miroir** : `ProviderContainer` dans `onStart`, `SessionMirror`, commandes, écrans sur le miroir. Test : balayer l'app pendant une veille simulée → la notification continue de se mettre à jour, réouverture = état vivant.
3. **Snapshot + reprise** : écriture périodique, reprise sur `TaskStarter.system`, tests unitaires de sérialisation et de la décision reprendre/abandonner. Test réel : `run-as … kill -9` pendant une veille → reprise.
4. **Samsung + garde-fou** : détection fabricant, lignes de réglage, bannière, heartbeat.

Estimation : 1,5 à 2 jours. Version cible : 1.1.0+4.

## Tests manuels de validation
1. Veille simulée, balayer l'app des récents : notification toujours vivante après 5 min, réouverture affiche la veille.
2. Veille réelle montre, écran éteint 30 min : BPM dans la notification à jour.
3. `adb shell run-as com.sleepstop.sleep_stop kill -9 <pid>` pendant une veille : service relancé, notification « Veille reprise », montre reconnectée.
4. Doze forcé (`dumpsys deviceidle force-idle`) : la veille continue.
5. Samsung « jamais en veille » activé : nuit complète sans interruption ; désactivé : interruption détectée et bannière le matin.
