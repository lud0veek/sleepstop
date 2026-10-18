import '../models/active_session_state.dart';
import '../models/sleep_settings.dart';

class AppStrings {
  final String lang;

  const AppStrings(this.lang);

  static const List<String> supportedLanguages = ['fr', 'nl', 'de', 'es'];

  static String flagFor(String code) => switch (code) {
    'fr' => '🇫🇷 FR',
    'nl' => '🇳🇱 NL',
    'de' => '🇩🇪 DE',
    'es' => '🇪🇸 ES',
    _ => '🇫🇷 FR',
  };

  static String languageName(String code) => switch (code) {
    'fr' => 'Français',
    'nl' => 'Nederlands',
    'de' => 'Deutsch',
    'es' => 'Español',
    _ => 'Français',
  };

  String tr({
    required String fr,
    required String nl,
    required String de,
    required String es,
  }) => switch (lang) {
    'nl' => nl,
    'de' => de,
    'es' => es,
    _ => fr,
  };

  // App Header & Tabs
  String get appSubtitle => tr(
    fr: 'Arrêt Média Intelligent au Sommeil',
    nl: 'Slimme Media Slaap-Stopper',
    de: 'Intelligenter Medien-Schlafstopper',
    es: 'Parada Inteligente de Medios al Dormir',
  );

  String get tabTonight => tr(
    fr: 'Ce soir',
    nl: 'Vannacht',
    de: 'Heute Nacht',
    es: 'Esta noche',
  );

  String get tabHistory => tr(
    fr: 'Historique',
    nl: 'Geschiedenis',
    de: 'Verlauf',
    es: 'Historial',
  );

  String get watchGuideTooltip => tr(
    fr: 'Guide des montres compatibles',
    nl: 'Gids voor compatibele horloges',
    de: 'Anleitung für kompatible Uhren',
    es: 'Guía de relojes compatibles',
  );

  String get settingsTooltip => tr(
    fr: 'Paramètres de détection',
    nl: 'Detectie-instellingen',
    de: 'Erkennungseinstellungen',
    es: 'Ajustes de detección',
  );

  // Mode Selector & Main Button
  String get modeWatchBle => tr(
    fr: 'Montre (BLE)',
    nl: 'Horloge (BLE)',
    de: 'Uhr (BLE)',
    es: 'Reloj (BLE)',
  );

  String get modePhoneShake => tr(
    fr: 'Téléphone (Secousse)',
    nl: 'Telefoon (Schudden)',
    de: 'Telefon (Schütteln)',
    es: 'Teléfono (Agitar)',
  );

  String get startSleepSession => tr(
    fr: 'Démarrer la veille',
    nl: 'Slaapsessie starten',
    de: 'Schlafsitzung starten',
    es: 'Iniciar sesión de sueño',
  );

  String get stopSession => tr(
    fr: 'Arrêter la session',
    nl: 'Sessie stoppen',
    de: 'Sitzung stoppen',
    es: 'Detener sesión',
  );

  String get startSubtitleWatch => tr(
    fr: 'Surveille le pouls BLE (0x180D) en arrière-plan écran éteint',
    nl: 'Volgt BLE-hartslag (0x180D) op de achtergrond met scherm uit',
    de: 'Überwacht BLE-Herzfrequenz (0x180D) im Hintergrund bei ausgeschaltetem Display',
    es: 'Monitoriza el pulso BLE (0x180D) en segundo plano con pantalla apagada',
  );

  String get startSubtitlePhone => tr(
    fr: 'Lance le compte à rebours avec détection de mouvement',
    nl: 'Start aftellen met bewegingsdetectie',
    de: 'Startet Countdown mit Bewegungserkennung',
    es: 'Inicia cuenta atrás con detección de movimiento',
  );

  String get stopSubtitle => tr(
    fr: 'Service actif • Tu peux verrouiller ton écran en toute sécurité',
    nl: 'Service actief • Je kunt je scherm veilig vergrendelen',
    de: 'Dienst aktiv • Du kannst dein Display sicher sperren',
    es: 'Servicio activo • Puedes bloquear tu pantalla con seguridad',
  );

  // Phase Status Badge translations
  String localizedPhaseStatus(ActiveSessionState session) {
    return switch (session.phase) {
      SessionPhase.idle => tr(
        fr: 'Prêt à démarrer la veille',
        nl: 'Klaar om slaapsessie te starten',
        de: 'Bereit für die Schlafsitzung',
        es: 'Listo para iniciar la sesión',
      ),
      SessionPhase.scanningBle || SessionPhase.connectingBle => tr(
        fr: 'Connexion à la montre BLE (0x180D)...',
        nl: 'Verbinden met BLE-horloge (0x180D)...',
        de: 'Verbinde mit BLE-Uhr (0x180D)...',
        es: 'Conectando al reloj BLE (0x180D)...',
      ),
      SessionPhase.calibratingBaseline => tr(
        fr: 'Calibration du pouls au repos (90s)...',
        nl: 'Hartslag in rust kalibreren (90s)...',
        de: 'Ruhepuls-Kalibrierung (90s)...',
        es: 'Calibrando pulso en reposo (90s)...',
      ),
      SessionPhase.monitoring => tr(
        fr: 'Surveillance active...',
        nl: 'Actieve bewaking...',
        de: 'Aktive Überwachung...',
        es: 'Vigilancia activa...',
      ),
      SessionPhase.hrDropping => tr(
        fr: 'Baisse du pouls détectée (endormissement)...',
        nl: 'Hartslagdaling gedetecteerd (inslapen)...',
        de: 'Herzfrequenzabfall erkannt (Einschlafen)...',
        es: 'Bajada de pulso detectada (durmiendo)...',
      ),
      SessionPhase.fadingAudio => tr(
        fr: 'Fondu sonore en cours (${session.fadeRemainingSeconds}s)...',
        nl: 'Audio-fade bezig (${session.fadeRemainingSeconds}s)...',
        de: 'Audio-Ausblendung (${session.fadeRemainingSeconds}s)...',
        es: 'Fundido de audio (${session.fadeRemainingSeconds}s)...',
      ),
      SessionPhase.pausedCompleted => tr(
        fr: 'Sommeil détecté • Média mis en pause',
        nl: 'Slaap gedetecteerd • Media gepauzeerd',
        de: 'Schlaf erkannt • Medien pausiert',
        es: 'Sueño detectado • Medios en pausa',
      ),
      SessionPhase.error => tr(
        fr: 'Aucune montre BLE trouvée (active Diffuser FC)',
        nl: 'Geen BLE-horloge gevonden (activeer Hartslag uitzenden)',
        de: 'Keine BLE-Uhr gefunden (HF senden aktivieren)',
        es: 'Reloj BLE no encontrado (activa Transmitir FC)',
      ),
    };
  }

  // Cards on Dashboard
  String get elapsedLabel => tr(
    fr: 'ÉCOULÉ',
    nl: 'VERSTREKEN',
    de: 'VERSTRICHEN',
    es: 'TRANSCURRIDO',
  );

  String get noWatchConnected => tr(
    fr: 'Aucune montre connectée (Diffuser FC / BLE 0x180D)',
    nl: 'Geen horloge verbonden (Hartslag uitzenden / BLE 0x180D)',
    de: 'Keine Uhr verbunden (HF senden / BLE 0x180D)',
    es: 'Ningún reloj conectado (Transmitir FC / BLE 0x180D)',
  );

  String get adaptiveTargetLabel => tr(
    fr: 'CIBLE ADAPTATIVE',
    nl: 'ADAPTIEF DOEL',
    de: 'ADAPTIVES ZIEL',
    es: 'META ADAPTATIVA',
  );

  String get thresholdLabel => tr(
    fr: 'SEUIL FIXE',
    nl: 'VASTE DREMPEL',
    de: 'SCHWELLENWERT',
    es: 'UMBRAL FIJO',
  );

  String awakeBaselineText(String bpm) => tr(
    fr: 'Éveillé : $bpm BPM',
    nl: 'Wakker: $bpm BPM',
    de: 'Wach: $bpm BPM',
    es: 'Despierto: $bpm BPM',
  );

  String get liveBleLabel => tr(
    fr: 'Direct BLE 0x2A37',
    nl: 'Live BLE 0x2A37',
    de: 'Live BLE 0x2A37',
    es: 'En vivo BLE 0x2A37',
  );

  String get waitingForHr => tr(
    fr: 'En attente FC',
    nl: 'Wachten op HS',
    de: 'Warte auf HF',
    es: 'Esperando FC',
  );

  String get hrStabilityTitle => tr(
    fr: 'STABILITÉ FC (60S)',
    nl: 'HS-STABILITEIT (60S)',
    de: 'HF-STABILITÄT (60S)',
    es: 'ESTABILIDAD FC (60S)',
  );

  String get calmPlateauLabel => tr(
    fr: 'Plateau calme',
    nl: 'Rustig plateau',
    de: 'Ruhiges Plateau',
    es: 'Meseta estable',
  );

  String get activeMovementLabel => tr(
    fr: 'Variable',
    nl: 'Actief',
    de: 'Aktiv',
    es: 'Activo',
  );

  String get collectingWindowLabel => tr(
    fr: 'Analyse sur 60s en cours...',
    nl: '60s-venster verzamelen...',
    de: '60s-Fenster wird erfasst...',
    es: 'Analizando ventana de 60s...',
  );

  String get sleepConfidenceLabel => tr(
    fr: 'Indice d\'endormissement',
    nl: 'Inslaap-zekerheid',
    de: 'Einschlaf-Konfidenz',
    es: 'Confianza de sueño',
  );

  String confirmationWindowLabel(int mins) => tr(
    fr: 'Fenêtre de confirmation (${mins}m)',
    nl: 'Bevestigingsvenster (${mins}m)',
    de: 'Bestätigungsfenster (${mins}m)',
    es: 'Ventana de confirmación (${mins}m)',
  );

  String get nextSleepCheckLabel => tr(
    fr: 'PROCHAIN TEST AUDIO DANS',
    nl: 'VOLGENDE SLAAPCHECK OVER',
    de: 'NÄCHSTER SCHLAFTEST IN',
    es: 'PRÓXIMA PRUEBA EN',
  );

  String get motionShakeLabel => tr(
    fr: 'MOUVEMENT / SECOUSSE',
    nl: 'BEWEGING / SCHUDDEN',
    de: 'BEWEGUNG / SCHÜTTELN',
    es: 'MOVIMIENTO / AGITAR',
  );

  String fadingVolumeLabel(int secs) => tr(
    fr: 'Fondu du volume (${secs}s restantes)',
    nl: 'Volume verlagen (${secs}s over)',
    de: 'Lautstärke senken (noch ${secs}s)',
    es: 'Bajando volumen (quedan ${secs}s)',
  );

  String get imAwakeRestoreBtn => tr(
    fr: 'Je suis éveillé — Rétablir le son',
    nl: 'Ik ben wakker — Volume herstellen',
    de: 'Ich bin wach — Ton wiederherstellen',
    es: 'Estoy despierto — Restaurar volumen',
  );

  String get resetTimerBtn => tr(
    fr: 'Relancer le minuteur',
    nl: 'Timer resetten',
    de: 'Timer zurücksetzen',
    es: 'Reiniciar temporizador',
  );

  String testFadeNowBtn(int secs) => tr(
    fr: 'Tester le fondu (${secs}s)',
    nl: 'Test fade nu (${secs}s)',
    de: 'Fade jetzt testen (${secs}s)',
    es: 'Probar fundido (${secs}s)',
  );

  String get simulateWatchBtn => tr(
    fr: 'Simuler une montre BLE (Démo)',
    nl: 'Simuleer BLE-horloge (Demo)',
    de: 'BLE-Uhr simulieren (Demo)',
    es: 'Simular reloj BLE (Demo)',
  );

  String get configureButton => tr(
    fr: 'Configurer',
    nl: 'Configureren',
    de: 'Anpassen',
    es: 'Configurar',
  );

  String get guideButton => tr(
    fr: 'Guide',
    nl: 'Gids',
    de: 'Anleitung',
    es: 'Guía',
  );

  String get addButton => tr(
    fr: 'Ajouter',
    nl: 'Toevoegen',
    de: 'Hinzufügen',
    es: 'Añadir',
  );

  String get appsToCloseTitle => tr(
    fr: 'Apps à fermer à l\'endormissement',
    nl: 'Apps sluiten bij inslapen',
    de: 'Apps beim Einschlafen schließen',
    es: 'Apps a cerrar al dormir',
  );

  String get appsPausedOnlyTitle => tr(
    fr: 'Pause média uniquement (sans fermer les apps)',
    nl: 'Alleen media pauzeren (apps niet sluiten)',
    de: 'Nur Medien pausieren (Apps nicht schließen)',
    es: 'Solo pausar medios (sin cerrar apps)',
  );

  String get noAppSelected => tr(
    fr: 'Aucune app sélectionnée',
    nl: 'Geen app geselecteerd',
    de: 'Keine App ausgewählt',
    es: 'Ninguna app seleccionada',
  );

  String get watchGuideBanner => tr(
    fr: 'Guide de connexion : Garmin, Whoop, Polar, Coros, Xiaomi...',
    nl: 'Verbindingsgids: Garmin, Whoop, Polar, Coros, Xiaomi...',
    de: 'Verbindungsanleitung: Garmin, Whoop, Polar, Coros, Xiaomi...',
    es: 'Guía de conexión: Garmin, Whoop, Polar, Coros, Xiaomi...',
  );

  String get quickTileTitle => tr(
    fr: 'Tuile de lancement rapide Android',
    nl: 'Android Snelkoppelingstegel',
    de: 'Android-Schnelleinstellungskachel',
    es: 'Acceso rápido de Android',
  );

  String get quickTileSubtitle => tr(
    fr: 'Lance ou arrête SleepStop en 1 clic depuis le volet de notifications',
    nl: 'Start of stop SleepStop met 1 tik vanuit het meldingenpaneel',
    de: 'SleepStop mit 1 Tipp über die Benachrichtigungsleiste starten/stoppen',
    es: 'Inicia o detén SleepStop con 1 toque desde el panel de notificaciones',
  );

  String get quickTileAddedMsg => tr(
    fr: 'Tuile SleepStop ajoutée à tes raccourcis rapides Android !',
    nl: 'SleepStop-tegel toegevoegd aan je snelle instellingen!',
    de: 'SleepStop-Kachel zu deinen Schnelleinstellungen hinzugefügt!',
    es: '¡Acceso rápido de SleepStop añadido a tus ajustes rápidos!',
  );

  String get quickTileAlreadyMsg => tr(
    fr: 'La tuile SleepStop est déjà dans ton volet de notifications.',
    nl: 'De SleepStop-tegel staat al in je meldingenpaneel.',
    de: 'Die SleepStop-Kachel befindet sich bereits in deiner Leiste.',
    es: 'El acceso rápido de SleepStop ya está en tu panel.',
  );

  String get quickTileManualMsg => tr(
    fr: 'Ouvre ton volet Android > Modifier (crayon) > glisse la tuile SleepStop.',
    nl: 'Open Android-paneel > Bewerken (potlood) > sleep de SleepStop-tegel.',
    de: 'Android-Leiste öffnen > Bearbeiten (Stift) > SleepStop-Kachel ziehen.',
    es: 'Abre el panel de Android > Editar (lápiz) > arrastra SleepStop.',
  );

  String smartAdaptiveSummary(AdaptiveSensitivity sens) => tr(
    fr: 'Adaptatif intelligent (${sensitivityTitle(sens)}) • Calibration 90s + Plateau FC',
    nl: 'Slim adaptief (${sensitivityTitle(sens)}) • 90s kalibratie + HS-plateau',
    de: 'Smart Adaptiv (${sensitivityTitle(sens)}) • 90s Kalibrierung + HF-Plateau',
    es: 'Adaptativo inteligente (${sensitivityTitle(sens)}) • Calibración 90s + Meseta FC',
  );

  String manualBpmSummary(int bpm, int mins) => tr(
    fr: 'Seuil manuel : ≤ $bpm BPM • Confirmation : ${mins}m',
    nl: 'Handmatig: ≤ $bpm BPM • Bevestiging: ${mins}m',
    de: 'Manuell: ≤ $bpm BPM • Bestätigung: ${mins}m',
    es: 'Manual: ≤ $bpm BPM • Confirmación: ${mins}m',
  );

  String phoneIntervalSummary(int mins, String shake) => tr(
    fr: 'Intervalle : ${mins}m • Secousse : $shake m/s²',
    nl: 'Interval: ${mins}m • Schudden: $shake m/s²',
    de: 'Intervall: ${mins}m • Schütteln: $shake m/s²',
    es: 'Intervalo: ${mins}m • Agitar: $shake m/s²',
  );

  String get universalControllerTitle => tr(
    fr: 'CONTRÔLEUR MÉDIA UNIVERSEL ANDROID',
    nl: 'UNIVERSELE ANDROID MEDIACONTROLLER',
    de: 'UNIVERSELLER ANDROID-MEDIENCONTROLLER',
    es: 'CONTROLADOR MULTIMEDIA UNIVERSAL ANDROID',
  );

  String get universalControllerDesc => tr(
    fr: 'Pilote Audible, YouTube, Spotify, Netflix & Twitch via AudioManager & MediaSession',
    nl: 'Bestuurt Audible, YouTube, Spotify, Netflix & Twitch via AudioManager & MediaSession',
    de: 'Steuert Audible, YouTube, Spotify, Netflix & Twitch über AudioManager & MediaSession',
    es: 'Controla Audible, YouTube, Spotify, Netflix y Twitch vía AudioManager y MediaSession',
  );

  String get rewindBtn => tr(
    fr: 'Reculer',
    nl: 'Terugspoelen',
    de: 'Zurückspulen',
    es: 'Rebobinar',
  );

  String get pauseMediaBtn => tr(
    fr: 'Tester Pause',
    nl: 'Pauzeer Media',
    de: 'Medien pausieren',
    es: 'Pausar Medios',
  );

  String get dispatchedRewindMsg => tr(
    fr: 'Commande Reculer envoyée au lecteur actif',
    nl: 'Terugspoel-opdracht verzonden naar actieve speler',
    de: 'Zurückspul-Befehl an aktiven Player gesendet',
    es: 'Comando Rebobinar enviado al reproductor activo',
  );

  String get dispatchedPauseMsg => tr(
    fr: 'Commande Pause envoyée au lecteur actif',
    nl: 'Pauze-opdracht verzonden naar actieve speler',
    de: 'Pause-Befehl an aktiven Player gesendet',
    es: 'Comando Pausa enviado al reproductor activo',
  );

  // Settings Bottom Sheet
  String get settingsSheetTitle => tr(
    fr: 'Réglages de Détection du Sommeil',
    nl: 'Slaapdetectie-instellingen',
    de: 'Schlaferkennungs-Einstellungen',
    es: 'Ajustes de Detección de Sueño',
  );

  String get settingsWatchSection => tr(
    fr: 'ALGORITHME BIOMÉTRIQUE MONTRE (GARMIN / BLE)',
    nl: 'SLIMME HORLOGE BIOMETRISCH ALGORITME (GARMIN / BLE)',
    de: 'SMARTWATCH BIOMETRIE-ALGORITHMUS (GARMIN / BLE)',
    es: 'ALGORITMO BIOMÉTRICO DEL RELOJ (GARMIN / BLE)',
  );

  String get smartAdaptiveLabel => tr(
    fr: 'Adaptatif (Auto)',
    nl: 'Slim Adaptief',
    de: 'Smart Adaptiv',
    es: 'Adaptativo (Auto)',
  );

  String get manualBpmLabel => tr(
    fr: 'BPM Manuel',
    nl: 'Handmatige BPM',
    de: 'Manuelle BPM',
    es: 'BPM Manual',
  );

  String get howSmartWorksTitle => tr(
    fr: 'Fonctionnement Adaptatif Intelligent (Style Firstbeat)',
    nl: 'Hoe Slim Adaptief werkt (Firstbeat-stijl)',
    de: 'Wie Smart Adaptiv funktioniert (Firstbeat-Stil)',
    es: 'Cómo funciona el Modo Adaptativo (Estilo Firstbeat)',
  );

  String get howSmartWorksBody => tr(
    fr: '1. Mesure ton pouls éveillé personnel pendant les 90 premières secondes.\n'
        '2. S\'adapte automatiquement que ton pouls au coucher soit haut (72 BPM) ou déjà bas (52 BPM).\n'
        '3. Confirme le sommeil quand le pouls baisse ET se stabilise sur un plateau calme (±1.8 BPM).',
    nl: '1. Meet je persoonlijke wakkere hartslag gedurende de eerste 90s.\n'
        '2. Past zich automatisch aan of je start-HS nu hoog (72 BPM) of al laag in bed is (52 BPM).\n'
        '3. Bevestigt slaap wanneer je HS daalt EN stabiliseert op een rustig plateau (±1.8 BPM).',
    de: '1. Misst deinen persönlichen Wachpuls in den ersten 90 Sekunden.\n'
        '2. Passt sich automatisch an, egal ob dein Startpuls hoch (72 BPM) oder niedrig (52 BPM) ist.\n'
        '3. Bestätigt den Schlaf, sobald der Puls sinkt UND ein ruhiges Plateau (±1.8 BPM) erreicht.',
    es: '1. Mide tu pulso personal despierto durante los primeros 90s.\n'
        '2. Se adapta automáticamente tanto si tu pulso inicial es alto (72 BPM) como bajo (52 BPM).\n'
        '3. Confirma el sueño cuando el pulso baja Y entra en una meseta estable (±1.8 BPM).',
  );

  String learnedSleepHrText(String bpm) => tr(
    fr: 'Pouls de sommeil appris : ~$bpm BPM',
    nl: 'Geleerde slaap-hartslag: ~$bpm BPM',
    de: 'Gelernter Schlafpuls: ~$bpm BPM',
    es: 'Pulso de sueño aprendido: ~$bpm BPM',
  );

  String get sensitivityProfileTitle => tr(
    fr: 'Profil de sensibilité',
    nl: 'Gevoeligheidsprofiel',
    de: 'Empfindlichkeitsprofil',
    es: 'Perfil de sensibilidad',
  );

  String sensitivityTitle(AdaptiveSensitivity preset) => switch (preset) {
    AdaptiveSensitivity.fast => tr(
      fr: 'Rapide (Sommeil léger N1)',
      nl: 'Snel (Lichte slaap N1)',
      de: 'Schnell (Leichtschlaf N1)',
      es: 'Rápido (Sueño ligero N1)',
    ),
    AdaptiveSensitivity.balanced => tr(
      fr: 'Équilibré (Recommandé)',
      nl: 'Gebalanceerd (Aanbevolen)',
      de: 'Ausgewogen (Empfohlen)',
      es: 'Equilibrado (Recomendado)',
    ),
    AdaptiveSensitivity.deep => tr(
      fr: 'Profond (Sommeil confirmé N2)',
      nl: 'Diep (Bevestigde slaap N2)',
      de: 'Tief (Bestätigter Schlaf N2)',
      es: 'Profundo (Sueño confirmado N2)',
    ),
  };

  String sensitivityDesc(AdaptiveSensitivity preset) => switch (preset) {
    AdaptiveSensitivity.fast => tr(
      fr: 'Coupe rapidement dès que le pouls baisse et se stabilise (~3 min)',
      nl: 'Stopt snel zodra de hartslag daalt en stabiliseert (~3 min)',
      de: 'Stoppt schnell, sobald der Puls sinkt und sich stabilisiert (~3 Min)',
      es: 'Pausa rápido en cuanto el pulso baja y se estabiliza (~3 min)',
    ),
    AdaptiveSensitivity.balanced => tr(
      fr: 'Équilibre idéal entre chute adaptative et plateau stable (~4 min)',
      nl: 'Ideale balans tussen adaptieve daling en stabiel plateau (~4 min)',
      de: 'Ideale Balance aus Pulsabfall und stabilem Plateau (~4 Min)',
      es: 'Equilibrio ideal entre bajada adaptativa y meseta estable (~4 min)',
    ),
    AdaptiveSensitivity.deep => tr(
      fr: 'Attend une stabilisation parasympathique plus longue (~6 min)',
      nl: 'Wacht op diepere parasympathische stabilisatie (~6 min)',
      de: 'Wartet auf tiefere parasympathische Stabilisierung (~6 Min)',
      es: 'Espera una estabilización parasimpática más profunda (~6 min)',
    ),
  };

  String get fixedBpmSliderLabel => tr(
    fr: 'Seuil BPM fixe d\'endormissement',
    nl: 'Vaste slaap-BPM drempel',
    de: 'Fester Schlaf-BPM-Schwellenwert',
    es: 'Umbral fijo de BPM para dormir',
  );

  String get confirmationSliderLabel => tr(
    fr: 'Durée de confirmation',
    nl: 'Bevestigingsduur',
    de: 'Bestätigungsdauer',
    es: 'Duración de confirmación',
  );

  String get settingsPhoneSection => tr(
    fr: 'MODE TÉLÉPHONE (FONDU & SECOUSSE)',
    nl: 'TELEFOONMODUS (SLIMME FADE & SCHUDDEN)',
    de: 'TELEFONMODUS (SMART FADE & SCHÜTTELN)',
    es: 'MODO TELÉFONO (FUNDIDO Y AGITAR)',
  );

  String get timerIntervalSliderLabel => tr(
    fr: 'Intervalle de vérification',
    nl: 'Controle-interval timer',
    de: 'Prüfintervall des Timers',
    es: 'Intervalo de comprobación',
  );

  String get shakeSensitivitySliderLabel => tr(
    fr: 'Sensibilité aux secousses (m/s²)',
    nl: 'Schudgevoeligheid (m/s²)',
    de: 'Schüttelempfindlichkeit (m/s²)',
    es: 'Sensibilidad al movimiento (m/s²)',
  );

  String get autoRewindTitle => tr(
    fr: 'Rembobinage automatique avant la pause',
    nl: 'Automatisch terugspoelen vóór pauzeren',
    de: 'Automatisches Zurückspulen vor dem Pausieren',
    es: 'Rebobinado automático antes de pausar',
  );

  String get autoRewindSubtitle => tr(
    fr: 'Envoie la commande Reculer juste avant de mettre le média en pause',
    nl: 'Stuurt terugspoel-opdracht vlak voor het pauzeren van media',
    de: 'Sendet kurz vor dem Pausieren den Zurückspul-Befehl',
    es: 'Envía el comando rebobinar justo antes de pausar el contenido',
  );

  // Pro & Trial Monetization Banner / Sheet
  String trialBadgeText(int remainingNights) => tr(
    fr: 'Essai gratuit : $remainingNights nuits restantes • Débloquer à vie',
    nl: 'Gratis proef: $remainingNights nachten over • Levenslang ontgrendelen',
    de: 'Gratis-Test: noch $remainingNights Nächte • Lebenslang freischalten',
    es: 'Prueba gratis: quedan $remainingNights noches • Desbloquear de por vida',
  );

  String get proActiveBadge => tr(
    fr: 'SleepStop Pro (À vie) activé',
    nl: 'SleepStop Pro (Levenslang) actief',
    de: 'SleepStop Pro (Lebenslang) aktiv',
    es: 'SleepStop Pro (De por vida) activo',
  );

  String get unlockProTitle => tr(
    fr: 'SleepStop Pro • Accès à vie',
    nl: 'SleepStop Pro • Levenslange toegang',
    de: 'SleepStop Pro • Lebenslanger Zugang',
    es: 'SleepStop Pro • Acceso de por vida',
  );

  String get unlockProSubtitle => tr(
    fr: '1 seul paiement unique (9,99 €) • Aucun abonnement • Zéro publicité',
    nl: 'Slechts 1 eenmalige betaling (€ 9,99) • Geen abonnement • Geen reclame',
    de: 'Nur 1 Einmalzahlung (9,99 €) • Kein Abo • Keine Werbung',
    es: '1 único pago (9,99 €) • Sin suscripción • Cero publicidad',
  );

  String get unlockProCta => tr(
    fr: 'Débloquer à vie — 9,99 €',
    nl: 'Levenslang ontgrendelen — € 9,99',
    de: 'Lebenslang freischalten — 9,99 €',
    es: 'Desbloquear de por vida — 9,99 €',
  );

  String get restorePurchaseBtn => tr(
    fr: 'Restaurer mon achat Google Play',
    nl: 'Google Play-aankoop herstellen',
    de: 'Google Play-Kauf wiederherstellen',
    es: 'Restaurar compra de Google Play',
  );

  // History Tab
  String get noSessionsYet => tr(
    fr: 'Aucune session enregistrée',
    nl: 'Nog geen sessies opgeslagen',
    de: 'Noch keine Sitzungen aufgezeichnet',
    es: 'Aún no hay sesiones registradas',
  );

  String get noSessionsDesc => tr(
    fr: 'Démarre une session avant d\'écouter Audible, Spotify ou YouTube. Dès que tu t\'endors, SleepStop enregistre l\'heure exacte, le chapitre et ta courbe cardiaque.',
    nl: 'Start een sessie voordat je naar Audible, Spotify of YouTube luistert. Zodra je in slaap valt, logt SleepStop het exacte tijdstip, hoofdstuk en je hartslagcurve.',
    de: 'Starte eine Sitzung vor dem Hören von Audible, Spotify oder YouTube. Sobald du einschläfst, speichert SleepStop die genaue Uhrzeit, das Kapitel und deine Herzfrequenzkurve.',
    es: 'Inicia una sesión antes de escuchar Audible, Spotify o YouTube. En cuanto te duermas, SleepStop registrará la hora exacta, el capítulo y tu curva cardíaca.',
  );

  String get clearHistoryBtn => tr(
    fr: 'Effacer',
    nl: 'Wissen',
    de: 'Löschen',
    es: 'Borrar',
  );

  String get startedLabel => tr(
    fr: 'Début session',
    nl: 'Start sessie',
    de: 'Sitzungsstart',
    es: 'Inicio sesión',
  );

  String get fellAsleepLabel => tr(
    fr: 'Endormi / Pause à',
    nl: 'Ingeslapen / Pauze om',
    de: 'Eingeschlafen / Pause um',
    es: 'Dormido / Pausa a las',
  );

  String get listenedForPrefix => tr(
    fr: 'Durée réelle d\'écoute',
    nl: 'Werkelijke luistertijd',
    de: 'Tatsächliche Hörzeit',
    es: 'Tiempo real escuchado',
  );

  String get closedPrefix => tr(
    fr: 'App fermée / mise en pause',
    nl: 'Gesloten / gepauzeerde app',
    de: 'Geschlossene / pausierte App',
    es: 'App cerrada / en pausa',
  );

  String get hrSleepCurveTitle => tr(
    fr: 'COURBE CARDIAQUE D\'ENDORMISSEMENT',
    nl: 'HARTSLAG-SLAAPCURVE',
    de: 'HERZFREQUENZ-SCHLAFKURVE',
    es: 'CURVA CARDÍACA DE SUEÑO',
  );

  String get triggerPrefix => tr(
    fr: 'Déclencheur : ',
    nl: 'Trigger: ',
    de: 'Auslöser: ',
    es: 'Activador: ',
  );

  // ===========================================================================
  // Foreground-service notification, Quick Settings tile & morning summary
  // (these leave the Flutter UI, so they must be localized explicitly)
  // ===========================================================================
  String get stopSessionButton => tr(
    fr: 'Arrêter la veille',
    nl: 'Bewaking stoppen',
    de: 'Überwachung beenden',
    es: 'Detener la vigilancia',
  );

  String get fgTitleWatch => tr(
    fr: 'SleepStop • Mode montre biométrique',
    nl: 'SleepStop • Biometrische horlogemodus',
    de: 'SleepStop • Biometrischer Uhrmodus',
    es: 'SleepStop • Modo reloj biométrico',
  );

  String get fgTitlePhone => tr(
    fr: 'SleepStop • Mode téléphone (fondu & secousse)',
    nl: 'SleepStop • Telefoonmodus (fade & schud)',
    de: 'SleepStop • Telefonmodus (Fade & Schütteln)',
    es: 'SleepStop • Modo teléfono (fundido y sacudida)',
  );

  String get fgConnectingWatch => tr(
    fr: 'Connexion à la montre cardio (BLE)…',
    nl: 'Verbinden met hartslaghorloge (BLE)…',
    de: 'Verbindung zur Pulsuhr (BLE)…',
    es: 'Conectando al reloj cardíaco (BLE)…',
  );

  String get fgSimulatedWatch => tr(
    fr: 'Surveillance d\'un pouls simulé…',
    nl: 'Gesimuleerde hartslag wordt bewaakt…',
    de: 'Simulierter Puls wird überwacht…',
    es: 'Vigilando un pulso simulado…',
  );

  String fgBpmTitle(String bpmLabel, int threshold) => tr(
    fr: 'SleepStop • $bpmLabel (cible ≤ $threshold BPM)',
    nl: 'SleepStop • $bpmLabel (doel ≤ $threshold BPM)',
    de: 'SleepStop • $bpmLabel (Ziel ≤ $threshold BPM)',
    es: 'SleepStop • $bpmLabel (objetivo ≤ $threshold BPM)',
  );

  String fgCalibrating(int secondsLeft) => tr(
    fr: 'Calibration du pouls éveillé (${secondsLeft}s)…',
    nl: 'Kalibratie wakkere hartslag (${secondsLeft}s)…',
    de: 'Kalibrierung des Wachpulses (${secondsLeft}s)…',
    es: 'Calibrando el pulso despierto (${secondsLeft}s)…',
  );

  String get fgMonitoring => tr(
    fr: 'Surveillance en cours…',
    nl: 'Bewaking actief…',
    de: 'Überwachung läuft…',
    es: 'Vigilancia en curso…',
  );

  String get fgStabilizing => tr(
    fr: 'Stabilisation du pouls…',
    nl: 'Hartslag stabiliseert…',
    de: 'Puls stabilisiert sich…',
    es: 'Estabilizando el pulso…',
  );

  String fgSleepOnset(int currentMin, int totalMin) => tr(
    fr: 'Endormissement en cours ($currentMin/$totalMin min)…',
    nl: 'Inslapen gedetecteerd ($currentMin/$totalMin min)…',
    de: 'Einschlafen erkannt ($currentMin/$totalMin min)…',
    es: 'Conciliando el sueño ($currentMin/$totalMin min)…',
  );

  String fgSleepConfirmedTitle(int bpm) => tr(
    fr: 'SleepStop • Sommeil confirmé ($bpm BPM)',
    nl: 'SleepStop • Slaap bevestigd ($bpm BPM)',
    de: 'SleepStop • Schlaf bestätigt ($bpm BPM)',
    es: 'SleepStop • Sueño confirmado ($bpm BPM)',
  );

  String fgFadingBody(int seconds) => tr(
    fr: 'Fondu sonore sur $seconds secondes…',
    nl: 'Geluid vervaagt over $seconds seconden…',
    de: 'Ton wird über $seconds Sekunden ausgeblendet…',
    es: 'Atenuando el sonido durante $seconds segundos…',
  );

  String get fgFadingTitle60 => tr(
    fr: 'SleepStop • Fondu sonore (60 s)',
    nl: 'SleepStop • Geluid vervaagt (60 s)',
    de: 'SleepStop • Ton wird ausgeblendet (60 s)',
    es: 'SleepStop • Fundido de sonido (60 s)',
  );

  String get fgFadingNudge => tr(
    fr: 'Bouge ou tapote ton téléphone pour continuer à écouter !',
    nl: 'Beweeg of tik op je telefoon om verder te luisteren!',
    de: 'Bewege oder tippe dein Telefon an, um weiterzuhören!',
    es: '¡Mueve o toca tu teléfono para seguir escuchando!',
  );

  String fgNextCheck(int minutes) => tr(
    fr: 'Prochain contrôle sonore dans $minutes min',
    nl: 'Volgende geluidscontrole over $minutes min',
    de: 'Nächste Tonprüfung in $minutes Min.',
    es: 'Próxima comprobación de sonido en $minutes min',
  );

  String get fgMovementTitle => tr(
    fr: 'SleepStop • Mouvement détecté !',
    nl: 'SleepStop • Beweging gedetecteerd!',
    de: 'SleepStop • Bewegung erkannt!',
    es: 'SleepStop • ¡Movimiento detectado!',
  );

  String fgMovementBody(int minutes) => tr(
    fr: 'Volume restauré. Compte à rebours relancé à $minutes min.',
    nl: 'Volume hersteld. Aftellen opnieuw gestart op $minutes min.',
    de: 'Lautstärke wiederhergestellt. Countdown auf $minutes Min. zurückgesetzt.',
    es: 'Volumen restaurado. Cuenta atrás reiniciada a $minutes min.',
  );

  // Quick Settings tile subtitles
  String get tileReady => tr(
    fr: 'Prêt à veiller',
    nl: 'Klaar om te waken',
    de: 'Bereit zu wachen',
    es: 'Listo para vigilar',
  );

  String get tileActive => tr(
    fr: 'Veille active',
    nl: 'Bewaking actief',
    de: 'Überwachung aktiv',
    es: 'Vigilancia activa',
  );

  String get tileConnectingWatch => tr(
    fr: 'Connexion montre…',
    nl: 'Horloge verbinden…',
    de: 'Uhr verbinden…',
    es: 'Conectando reloj…',
  );

  String get tileSimulatedActive => tr(
    fr: 'Veille simulée active',
    nl: 'Gesimuleerde bewaking actief',
    de: 'Simulierte Überwachung aktiv',
    es: 'Vigilancia simulada activa',
  );

  String get tileWatchNotFound => tr(
    fr: 'Montre non trouvée',
    nl: 'Horloge niet gevonden',
    de: 'Uhr nicht gefunden',
    es: 'Reloj no encontrado',
  );

  String tileActiveWatch(String watchName) => tr(
    fr: 'Actif • $watchName',
    nl: 'Actief • $watchName',
    de: 'Aktiv • $watchName',
    es: 'Activo • $watchName',
  );

  String tileActiveBpm(String bpmLabel, int threshold) => tr(
    fr: 'Actif • $bpmLabel (≤$threshold)',
    nl: 'Actief • $bpmLabel (≤$threshold)',
    de: 'Aktiv • $bpmLabel (≤$threshold)',
    es: 'Activo • $bpmLabel (≤$threshold)',
  );

  String tileActiveCheck(int minutes) => tr(
    fr: 'Actif • Contrôle dans ${minutes}m',
    nl: 'Actief • Controle over ${minutes}m',
    de: 'Aktiv • Prüfung in ${minutes}m',
    es: 'Activo • Control en ${minutes}m',
  );

  String tileSleepDetectedBpm(int bpm) => tr(
    fr: 'Sommeil détecté ($bpm BPM)',
    nl: 'Slaap gedetecteerd ($bpm BPM)',
    de: 'Schlaf erkannt ($bpm BPM)',
    es: 'Sueño detectado ($bpm BPM)',
  );

  String get tileSleepDetectedPaused => tr(
    fr: 'Sommeil détecté • Pause',
    nl: 'Slaap gedetecteerd • Pauze',
    de: 'Schlaf erkannt • Pause',
    es: 'Sueño detectado • Pausa',
  );

  // History trigger reasons (stored in the log at detection time)
  String triggerReasonHr(int bpm, {double? baselineBpm, double? stdDevBpm}) {
    final from = baselineBpm != null
        ? tr(
            fr: ' depuis ${baselineBpm.toStringAsFixed(0)} BPM',
            nl: ' vanaf ${baselineBpm.toStringAsFixed(0)} BPM',
            de: ' von ${baselineBpm.toStringAsFixed(0)} BPM',
            es: ' desde ${baselineBpm.toStringAsFixed(0)} BPM',
          )
        : '';
    final plateau = stdDevBpm != null
        ? tr(
            fr: ' (plateau ±${stdDevBpm.toStringAsFixed(1)} BPM)',
            nl: ' (plateau ±${stdDevBpm.toStringAsFixed(1)} BPM)',
            de: ' (Plateau ±${stdDevBpm.toStringAsFixed(1)} BPM)',
            es: ' (meseta ±${stdDevBpm.toStringAsFixed(1)} BPM)',
          )
        : '';
    return tr(
      fr: 'Pouls stabilisé à $bpm BPM$from$plateau',
      nl: 'Hartslag gestabiliseerd op $bpm BPM$from$plateau',
      de: 'Puls stabil bei $bpm BPM$from$plateau',
      es: 'Pulso estabilizado en $bpm BPM$from$plateau',
    );
  }

  String get triggerReasonFade => tr(
    fr: 'Aucune réaction au fondu sonore',
    nl: 'Geen reactie op het vervagende geluid',
    de: 'Keine Reaktion auf das Ausblenden',
    es: 'Sin reacción al fundido de sonido',
  );

  // Morning summary notification
  String summaryTitle(String asleepTime, String duration) => tr(
    fr: 'Média mis en pause à $asleepTime • Reviens de $duration',
    nl: 'Media gepauzeerd om $asleepTime • Spoel $duration terug',
    de: 'Medien pausiert um $asleepTime • Spule $duration zurück',
    es: 'Medios en pausa a las $asleepTime • Retrocede $duration',
  );

  String summaryBody(
    String startTime,
    String asleepTime,
    String duration,
    String reason,
  ) => tr(
    fr: 'Session : $startTime → $asleepTime ($duration écoutées). Raison : $reason.',
    nl: 'Sessie: $startTime → $asleepTime ($duration geluisterd). Reden: $reason.',
    de: 'Sitzung: $startTime → $asleepTime ($duration gehört). Grund: $reason.',
    es: 'Sesión: $startTime → $asleepTime ($duration escuchados). Motivo: $reason.',
  );

  String get summaryChannelName => tr(
    fr: 'Résumé du matin',
    nl: 'Ochtendoverzicht',
    de: 'Morgenzusammenfassung',
    es: 'Resumen de la mañana',
  );

  String get summaryChannelDesc => tr(
    fr: 'Indique quand le média a été mis en pause et de combien revenir en arrière.',
    nl: 'Toont wanneer de media gepauzeerd werd en hoever je moet terugspoelen.',
    de: 'Zeigt, wann die Wiedergabe pausiert wurde und wie weit zurückzuspulen ist.',
    es: 'Indica cuándo se pausó el medio y cuánto retroceder.',
  );

  String get summaryFooter => tr(
    fr: 'SleepStop • Aide au retour en arrière',
    nl: 'SleepStop • Terugspoelhulp',
    de: 'SleepStop • Zurückspul-Hilfe',
    es: 'SleepStop • Ayuda para retroceder',
  );

  String get fgChannelName => tr(
    fr: 'Veille SleepStop active',
    nl: 'SleepStop-bewaking actief',
    de: 'SleepStop-Überwachung aktiv',
    es: 'Vigilancia SleepStop activa',
  );

  String get fgChannelDesc => tr(
    fr: 'Maintient la détection du sommeil (pouls et mouvement) écran éteint.',
    nl: 'Houdt slaapdetectie (hartslag en beweging) actief met het scherm uit.',
    de: 'Hält die Schlaferkennung (Puls und Bewegung) bei ausgeschaltetem Bildschirm aktiv.',
    es: 'Mantiene la detección del sueño (pulso y movimiento) con la pantalla apagada.',
  );

  // ===========================================================================
  // First-start permission explainer
  // ===========================================================================
  String get permTitle => tr(
    fr: 'Avant la première veille',
    nl: 'Vóór de eerste bewaking',
    de: 'Vor der ersten Überwachung',
    es: 'Antes de la primera vigilancia',
  );

  String get permIntro => tr(
    fr: 'SleepStop va te demander trois autorisations Android. Voici pourquoi chacune est nécessaire.',
    nl: 'SleepStop vraagt je drie Android-toestemmingen. Dit is waarom elke nodig is.',
    de: 'SleepStop fragt dich nach drei Android-Berechtigungen. Darum wird jede gebraucht.',
    es: 'SleepStop te pedirá tres permisos de Android. Esto es por qué cada uno es necesario.',
  );

  String get permBluetoothTitle => tr(
    fr: 'Appareils à proximité (Bluetooth)',
    nl: 'Apparaten in de buurt (Bluetooth)',
    de: 'Geräte in der Nähe (Bluetooth)',
    es: 'Dispositivos cercanos (Bluetooth)',
  );

  String get permBluetoothBody => tr(
    fr: 'Pour lire le pouls diffusé par ta montre. Utilisé uniquement en mode montre.',
    nl: 'Om de hartslag van je horloge te lezen. Alleen gebruikt in horlogemodus.',
    de: 'Um den von deiner Uhr gesendeten Puls zu lesen. Nur im Uhrmodus verwendet.',
    es: 'Para leer el pulso que emite tu reloj. Solo se usa en modo reloj.',
  );

  String get permNotifTitle => tr(
    fr: 'Notifications',
    nl: 'Meldingen',
    de: 'Benachrichtigungen',
    es: 'Notificaciones',
  );

  String get permNotifBody => tr(
    fr: 'Pour afficher la veille en cours et le résumé du matin (heure d\'endormissement, retour en arrière).',
    nl: 'Om de lopende bewaking en het ochtendoverzicht te tonen (inslaaptijd, terugspoelen).',
    de: 'Um die laufende Überwachung und die Morgenzusammenfassung anzuzeigen (Einschlafzeit, Zurückspulen).',
    es: 'Para mostrar la vigilancia en curso y el resumen de la mañana (hora de dormirse, retroceso).',
  );

  String get permBatteryTitle => tr(
    fr: 'Pas d\'optimisation de batterie',
    nl: 'Geen batterijoptimalisatie',
    de: 'Keine Akku-Optimierung',
    es: 'Sin optimización de batería',
  );

  String get permBatteryBody => tr(
    fr: 'Pour qu\'Android ne coupe pas la surveillance écran éteint. La consommation reste très faible (BLE + accéléromètre).',
    nl: 'Zodat Android de bewaking niet stopt met het scherm uit. Het verbruik blijft heel laag (BLE + bewegingssensor).',
    de: 'Damit Android die Überwachung bei ausgeschaltetem Bildschirm nicht beendet. Der Verbrauch bleibt sehr gering (BLE + Beschleunigungssensor).',
    es: 'Para que Android no corte la vigilancia con la pantalla apagada. El consumo sigue siendo muy bajo (BLE + acelerómetro).',
  );

  String get permContinue => tr(
    fr: 'Continuer',
    nl: 'Doorgaan',
    de: 'Weiter',
    es: 'Continuar',
  );

  String get permNotNow => tr(
    fr: 'Pas maintenant',
    nl: 'Niet nu',
    de: 'Nicht jetzt',
    es: 'Ahora no',
  );
}
