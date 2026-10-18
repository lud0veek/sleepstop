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

  String _t({
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
  String get appSubtitle => _t(
    fr: 'Arrêt Média Intelligent au Sommeil',
    nl: 'Slimme Media Slaap-Stopper',
    de: 'Intelligenter Medien-Schlafstopper',
    es: 'Parada Inteligente de Medios al Dormir',
  );

  String get tabTonight => _t(
    fr: 'Ce soir',
    nl: 'Vannacht',
    de: 'Heute Nacht',
    es: 'Esta noche',
  );

  String get tabHistory => _t(
    fr: 'Historique',
    nl: 'Geschiedenis',
    de: 'Verlauf',
    es: 'Historial',
  );

  String get watchGuideTooltip => _t(
    fr: 'Guide des montres compatibles',
    nl: 'Gids voor compatibele horloges',
    de: 'Anleitung für kompatible Uhren',
    es: 'Guía de relojes compatibles',
  );

  String get settingsTooltip => _t(
    fr: 'Paramètres de détection',
    nl: 'Detectie-instellingen',
    de: 'Erkennungseinstellungen',
    es: 'Ajustes de detección',
  );

  // Mode Selector & Main Button
  String get modeWatchBle => _t(
    fr: 'Montre (BLE)',
    nl: 'Horloge (BLE)',
    de: 'Uhr (BLE)',
    es: 'Reloj (BLE)',
  );

  String get modePhoneShake => _t(
    fr: 'Téléphone (Secousse)',
    nl: 'Telefoon (Schudden)',
    de: 'Telefon (Schütteln)',
    es: 'Teléfono (Agitar)',
  );

  String get startSleepSession => _t(
    fr: 'Démarrer la veille',
    nl: 'Slaapsessie starten',
    de: 'Schlafsitzung starten',
    es: 'Iniciar sesión de sueño',
  );

  String get stopSession => _t(
    fr: 'Arrêter la session',
    nl: 'Sessie stoppen',
    de: 'Sitzung stoppen',
    es: 'Detener sesión',
  );

  String get startSubtitleWatch => _t(
    fr: 'Surveille le pouls BLE (0x180D) en arrière-plan écran éteint',
    nl: 'Volgt BLE-hartslag (0x180D) op de achtergrond met scherm uit',
    de: 'Überwacht BLE-Herzfrequenz (0x180D) im Hintergrund bei ausgeschaltetem Display',
    es: 'Monitoriza el pulso BLE (0x180D) en segundo plano con pantalla apagada',
  );

  String get startSubtitlePhone => _t(
    fr: 'Lance le compte à rebours avec détection de mouvement',
    nl: 'Start aftellen met bewegingsdetectie',
    de: 'Startet Countdown mit Bewegungserkennung',
    es: 'Inicia cuenta atrás con detección de movimiento',
  );

  String get stopSubtitle => _t(
    fr: 'Restaure le volume initial et arrête le service de veille',
    nl: 'Herstelt origineel volume en stopt achtergrondservice',
    de: 'Stellt die ursprüngliche Lautstärke wieder her und beendet den Dienst',
    es: 'Restaura el volumen original y detiene el servicio en segundo plano',
  );

  // Cards on Dashboard
  String get elapsedLabel => _t(
    fr: 'ÉCOULÉ',
    nl: 'VERSTREKEN',
    de: 'VERSTRICHEN',
    es: 'TRANSCURRIDO',
  );

  String get noWatchConnected => _t(
    fr: 'Aucune montre connectée (Diffuser FC / BLE 0x180D)',
    nl: 'Geen horloge verbonden (Hartslag uitzenden / BLE 0x180D)',
    de: 'Keine Uhr verbunden (HF senden / BLE 0x180D)',
    es: 'Ningún reloj conectado (Transmitir FC / BLE 0x180D)',
  );

  String get adaptiveTargetLabel => _t(
    fr: 'CIBLE ADAPTATIVE',
    nl: 'ADAPTIEF DOEL',
    de: 'ADAPTIVES ZIEL',
    es: 'META ADAPTATIVA',
  );

  String get thresholdLabel => _t(
    fr: 'SEUIL FIXE',
    nl: 'VASTE DREMPEL',
    de: 'FESTER SCHWELLENWERT',
    es: 'UMBRAL FIJO',
  );

  String get waitingForHr => _t(
    fr: 'En attente FC',
    nl: 'Wachten op HS',
    de: 'Warte auf HF',
    es: 'Esperando FC',
  );

  String get simulateWatchBtn => _t(
    fr: 'Simuler Montre (Test)',
    nl: 'Simuleer Horloge (Test)',
    de: 'Uhr simulieren (Test)',
    es: 'Simular Reloj (Test)',
  );

  String get testSleepFadeBtn => _t(
    fr: 'Tester le fondu (10s)',
    nl: 'Slaap-fade testen (10s)',
    de: 'Schlaf-Fade testen (10s)',
    es: 'Probar fundido (10s)',
  );

  String get tuneButton => _t(
    fr: 'Régler',
    nl: 'Instellen',
    de: 'Anpassen',
    es: 'Ajustar',
  );

  String get configureButton => _t(
    fr: 'Configurer',
    nl: 'Configureren',
    de: 'Konfigurieren',
    es: 'Configurar',
  );

  String get guideButton => _t(
    fr: 'Guide',
    nl: 'Gids',
    de: 'Anleitung',
    es: 'Guía',
  );

  String get addButton => _t(
    fr: 'Ajouter',
    nl: 'Toevoegen',
    de: 'Hinzufügen',
    es: 'Añadir',
  );

  String get appsToCloseTitle => _t(
    fr: 'Apps à fermer à l\'endormissement',
    nl: 'Apps sluiten bij inslapen',
    de: 'Apps beim Einschlafen schließen',
    es: 'Apps a cerrar al dormir',
  );

  String get appsPausedOnlyTitle => _t(
    fr: 'Pause média uniquement (sans fermer les apps)',
    nl: 'Alleen media pauzeren (apps niet sluiten)',
    de: 'Nur Medien pausieren (Apps nicht schließen)',
    es: 'Solo pausar medios (sin cerrar apps)',
  );

  String get noAppSelected => _t(
    fr: 'Aucune app sélectionnée',
    nl: 'Geen app geselecteerd',
    de: 'Keine App ausgewählt',
    es: 'Ninguna app seleccionada',
  );

  String get watchGuideBanner => _t(
    fr: 'Guide de connexion : Garmin, Whoop, Polar, Coros, Xiaomi...',
    nl: 'Verbindingsgids: Garmin, Whoop, Polar, Coros, Xiaomi...',
    de: 'Verbindungsanleitung: Garmin, Whoop, Polar, Coros, Xiaomi...',
    es: 'Guía de conexión: Garmin, Whoop, Polar, Coros, Xiaomi...',
  );

  String get quickTileTitle => _t(
    fr: 'Tuile de lancement rapide Android',
    nl: 'Android Snelkoppelingstegel',
    de: 'Android-Schnelleinstellungskachel',
    es: 'Acceso rápido de Android',
  );

  String get quickTileSubtitle => _t(
    fr: 'Lance ou arrête SleepStop en 1 clic depuis le volet de notifications',
    nl: 'Start of stop SleepStop met 1 tik vanuit het meldingenpaneel',
    de: 'SleepStop mit 1 Tipp über die Benachrichtigungsleiste starten/stoppen',
    es: 'Inicia o detén SleepStop con 1 toque desde el panel de notificaciones',
  );

  String get quickTileAddedMsg => _t(
    fr: 'Tuile SleepStop ajoutée à tes raccourcis rapides Android !',
    nl: 'SleepStop-tegel toegevoegd aan je snelle instellingen!',
    de: 'SleepStop-Kachel zu deinen Schnelleinstellungen hinzugefügt!',
    es: '¡Acceso rápido de SleepStop añadido a tus ajustes rápidos!',
  );

  String get quickTileAlreadyMsg => _t(
    fr: 'La tuile SleepStop est déjà dans ton volet de notifications.',
    nl: 'De SleepStop-tegel staat al in je meldingenpaneel.',
    de: 'Die SleepStop-Kachel befindet sich bereits in deiner Leiste.',
    es: 'El acceso rápido de SleepStop ya está en tu panel.',
  );

  String get quickTileManualMsg => _t(
    fr: 'Ouvre ton volet Android > Modifier (crayon) > glisse la tuile SleepStop.',
    nl: 'Open Android-paneel > Bewerken (potlood) > sleep de SleepStop-tegel.',
    de: 'Android-Leiste öffnen > Bearbeiten (Stift) > SleepStop-Kachel ziehen.',
    es: 'Abre el panel de Android > Editar (lápiz) > arrastra SleepStop.',
  );

  String get systemMediaBridgeTitle => _t(
    fr: 'Pont Média Système Android',
    nl: 'Android Systeem Mediabrug',
    de: 'Android-System-Medienbrücke',
    es: 'Puente Multimedia de Android',
  );

  String get testPauseTitle => _t(
    fr: 'Tester Pause (Audible / YouTube / Spotify)',
    nl: 'Test Pauze (Audible / YouTube / Spotify)',
    de: 'Pause testen (Audible / YouTube / Spotify)',
    es: 'Probar Pausa (Audible / YouTube / Spotify)',
  );

  // Pro & Trial Monetization Banner / Sheet
  String trialBadgeText(int remainingNights) => _t(
    fr: 'Essai gratuit : $remainingNights nuits restantes • Débloquer à vie',
    nl: 'Gratis proef: $remainingNights nachten over • Levenslang ontgrendelen',
    de: 'Gratis-Test: noch $remainingNights Nächte • Lebenslang freischalten',
    es: 'Prueba gratis: quedan $remainingNights noches • Desbloquear de por vida',
  );

  String get proActiveBadge => _t(
    fr: 'SleepStop Pro (À vie) activé',
    nl: 'SleepStop Pro (Levenslang) actief',
    de: 'SleepStop Pro (Lebenslang) aktiv',
    es: 'SleepStop Pro (De por vida) activo',
  );

  String get unlockProTitle => _t(
    fr: 'SleepStop Pro • Accès à vie',
    nl: 'SleepStop Pro • Levenslange toegang',
    de: 'SleepStop Pro • Lebenslanger Zugang',
    es: 'SleepStop Pro • Acceso de por vida',
  );

  String get unlockProSubtitle => _t(
    fr: '1 seul paiement unique (4,99 €) • Aucun abonnement • Zéro publicité',
    nl: 'Slechts 1 eenmalige betaling (€ 4,99) • Geen abonnement • Geen reclame',
    de: 'Nur 1 Einmalzahlung (4,99 €) • Kein Abo • Keine Werbung',
    es: '1 único pago (4,99 €) • Sin suscripción • Cero publicidad',
  );

  String get unlockProCta => _t(
    fr: 'Débloquer à vie — 4,99 €',
    nl: 'Levenslang ontgrendelen — € 4,99',
    de: 'Lebenslang freischalten — 4,99 €',
    es: 'Desbloquear de por vida — 4,99 €',
  );

  String get restorePurchaseBtn => _t(
    fr: 'Restaurer mon achat Google Play',
    nl: 'Google Play-aankoop herstellen',
    de: 'Google Play-Kauf wiederherstellen',
    es: 'Restaurar compra de Google Play',
  );

  // History Tab
  String get noSessionsYet => _t(
    fr: 'Aucune session enregistrée',
    nl: 'Nog geen sessies opgeslagen',
    de: 'Noch keine Sitzungen aufgezeichnet',
    es: 'Aún no hay sesiones registradas',
  );

  String get noSessionsDesc => _t(
    fr: 'Démarre une session avant d\'écouter Audible, Spotify ou YouTube. Dès que tu t\'endors, SleepStop enregistre l\'heure exacte, le chapitre et ta courbe cardiaque.',
    nl: 'Start een sessie voordat je naar Audible, Spotify of YouTube luistert. Zodra je in slaap valt, logt SleepStop het exacte tijdstip, hoofdstuk en je hartslagcurve.',
    de: 'Starte eine Sitzung vor dem Hören von Audible, Spotify oder YouTube. Sobald du einschläfst, speichert SleepStop die genaue Uhrzeit, das Kapitel und deine Herzfrequenzkurve.',
    es: 'Inicia una sesión antes de escuchar Audible, Spotify o YouTube. En cuanto te duermas, SleepStop registrará la hora exacta, el capítulo y tu curva cardíaca.',
  );

  String get sleepSessionLogsTitle => _t(
    fr: 'Journal de tes nuits',
    nl: 'Slaapsessie-logboek',
    de: 'Schlafsitzungs-Protokoll',
    es: 'Registro de sesiones de sueño',
  );

  String get clearHistoryBtn => _t(
    fr: 'Effacer',
    nl: 'Wissen',
    de: 'Löschen',
    es: 'Borrar',
  );

  String get bookmarkOffsetTip => _t(
    fr: 'Astuce signet : recule ton livre audio à l\'heure "Endormi à" pour reprendre exactement où tu étais éveillé.',
    nl: 'Bladwijzertip: spoel je luisterboek terug naar "Ingeslapen om" om verder te gaan waar je nog wakker was.',
    de: 'Lesezeichen-Tipp: Spule dein Hörbuch zur Zeit „Eingeschlafen um" zurück.',
    es: 'Consejo: rebobina tu audiolibro hasta la hora "Dormido a las" para retomar donde estabas despierto.',
  );

  String get startedLabel => _t(
    fr: 'DÉBUT',
    nl: 'START',
    de: 'START',
    es: 'INICIO',
  );

  String get fellAsleepLabel => _t(
    fr: 'ENDORMI À',
    nl: 'INGESLAPEN OM',
    de: 'EINGESCHLAFEN UM',
    es: 'DORMIDO A LAS',
  );

  String get mediaPausedLabel => _t(
    fr: 'MÉDIA COUPÉ',
    nl: 'MEDIA GEPAUZEERD',
    de: 'MEDIEN PAUSIERT',
    es: 'MEDIOS PAUSADOS',
  );

  String get listenedForPrefix => _t(
    fr: 'Écouté pendant',
    nl: 'Geluisterd gedurende',
    de: 'Gehört für',
    es: 'Escuchado durante',
  );

  String get closedPrefix => _t(
    fr: 'Fermé',
    nl: 'Gesloten',
    de: 'Geschlossen',
    es: 'Cerrado',
  );
}
