import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_session_provider.dart';
import '../services/media_control_service.dart';
import 'theme/oled_theme.dart';

class TargetAppsSheet extends ConsumerStatefulWidget {
  const TargetAppsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (_, controller) =>
            TargetAppsSheetContent(scrollController: controller),
      ),
    );
  }

  @override
  ConsumerState<TargetAppsSheet> createState() => _TargetAppsSheetState();
}

class _TargetAppsSheetState extends ConsumerState<TargetAppsSheet> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TargetAppsSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const TargetAppsSheetContent({super.key, required this.scrollController});

  @override
  ConsumerState<TargetAppsSheetContent> createState() =>
      _TargetAppsSheetContentState();
}

class _TargetAppsSheetContentState
    extends ConsumerState<TargetAppsSheetContent> {
  List<InstalledAppEntry> _installedApps = const [];
  bool _loadingApps = true;
  bool _notifListenerEnabled = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final mediaService = ref.read(mediaControlServiceProvider);
    final notifEnabled = await mediaService.isNotificationListenerEnabled();
    final apps = await mediaService.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _notifListenerEnabled = notifEnabled;
      _installedApps = apps;
      _loadingApps = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final filteredApps = _installedApps.where((app) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return app.appName.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OledColors.subtleBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.appsToCloseTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OledColors.textPrimary,
                    ),
                  ),
                  Text(
                    s.tr(
                      fr: 'Coupe le son, quitte le plein écran vidéo et ferme les apps choisies',
                      nl: 'Dempt audio, verlaat volledig scherm en sluit gekozen apps',
                      de: 'Schaltet Ton stumm, beendet Vollbild und schließt gewählte Apps',
                      es: 'Silencia el audio, sale de pantalla completa y cierra las apps elegidas',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: OledColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: OledColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Notification Listener permission banner for exact chapter/video logging
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _notifListenerEnabled
                ? OledColors.calmTeal.withValues(alpha: 0.12)
                : OledColors.warmAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _notifListenerEnabled
                  ? OledColors.calmTeal.withValues(alpha: 0.4)
                  : OledColors.warmAmber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _notifListenerEnabled
                    ? Icons.check_circle_outline_rounded
                    : Icons.auto_stories_outlined,
                color: _notifListenerEnabled
                    ? OledColors.calmTeal
                    : OledColors.warmAmber,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _notifListenerEnabled
                          ? s.tr(
                              fr: 'Détection du titre & de l\'app active : ACTIVÉE',
                              nl: 'Detectie van titel & actieve app: AAN',
                              de: 'Erkennung von Titel & aktiver App: AKTIV',
                              es: 'Detección de título y app activa: ACTIVADA',
                            )
                          : s.tr(
                              fr: 'Identifier l\'app exacte & le titre du chapitre dans les logs',
                              nl: 'Identificeer exacte app & hoofdstuktitel in geschiedenis',
                              de: 'Genaue App & Kapiteltitel im Verlauf protokollieren',
                              es: 'Identificar la app exacta y el título del capítulo en el historial',
                            ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OledColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _notifListenerEnabled
                          ? s.tr(
                              fr: 'SleepStop enregistrera automatiquement le nom du lecteur et le titre du média joué.',
                              nl: 'SleepStop slaat automatisch de naam van de speler en de mediatitel op.',
                              de: 'SleepStop speichert automatisch den Namen des Players und den Medientitel.',
                              es: 'SleepStop guardará automáticamente el nombre del reproductor y el título del medio.',
                            )
                          : s.tr(
                              fr: 'Autorise « SleepStop Media Detector » pour voir le nom exact du livre/vidéo dans ton historique du matin.',
                              nl: 'Geef toestemming aan "SleepStop Media Detector" om de exacte boek-/videotitel te zien.',
                              de: 'Erlaube „SleepStop Media Detector“, um den genauen Buch-/Videotitel im Verlauf zu sehen.',
                              es: 'Autoriza «SleepStop Media Detector» para ver el título exacto del libro/vídeo en tu historial.',
                            ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_notifListenerEnabled) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(mediaControlServiceProvider)
                        .openNotificationListenerSettings();
                    await Future<void>.delayed(const Duration(seconds: 1));
                    _loadData();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OledColors.warmAmber,
                    side: const BorderSide(color: OledColors.warmAmber),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    s.tr(
                      fr: 'Activer',
                      nl: 'Activeren',
                      de: 'Aktivieren',
                      es: 'Activar',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search field
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: OledColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: s.tr(
              fr: 'Rechercher une application installée...',
              nl: 'Zoek een geïnstalleerde app...',
              de: 'Installierte App suchen...',
              es: 'Buscar una aplicación instalada...',
            ),
            hintStyle: const TextStyle(
              color: OledColors.textMuted,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: OledColors.textSecondary,
              size: 20,
            ),
            filled: true,
            fillColor: OledColors.elevatedSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OledColors.subtleBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OledColors.subtleBorder),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_loadingApps)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: OledColors.warmAmber),
            ),
          )
        else ...[
          Text(
            s.tr(
              fr: 'APPLICATIONS SÉLECTIONNÉES (${settings.targetAppsToClose.length})',
              nl: 'GESELECTEERDE APPS (${settings.targetAppsToClose.length})',
              de: 'AUSGEWÄHLTE APPS (${settings.targetAppsToClose.length})',
              es: 'APLICACIONES SELECCIONADAS (${settings.targetAppsToClose.length})',
            ),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OledColors.warmAmber,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: settings.targetAppsToClose.entries.map((entry) {
              return Chip(
                backgroundColor: OledColors.warmAmber.withValues(alpha: 0.15),
                side: BorderSide(
                  color: OledColors.warmAmber.withValues(alpha: 0.45),
                ),
                label: Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OledColors.warmAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                deleteIcon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: OledColors.warmAmber,
                ),
                onDeleted: () =>
                    notifier.toggleTargetApp(entry.key, entry.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            s.tr(
              fr: 'TOUTES TES APPLICATIONS INSTALLÉES',
              nl: 'ALLE GEÏNSTALLEERDE APPS',
              de: 'ALLE INSTALLIERTEN APPS',
              es: 'TODAS TUS APLICACIONES INSTALADAS',
            ),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OledColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...filteredApps.map((app) {
            final isSelected = settings.targetAppsToClose.containsKey(
              app.packageName,
            );
            return CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              activeColor: OledColors.warmAmber,
              checkColor: OledColors.trueBlack,
              value: isSelected,
              onChanged: (_) =>
                  notifier.toggleTargetApp(app.packageName, app.appName),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      app.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OledColors.textPrimary,
                      ),
                    ),
                  ),
                  if (app.isMediaCandidate) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: OledColors.softIndigo.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.tr(
                          fr: 'Média',
                          nl: 'Media',
                          de: 'Medien',
                          es: 'Medios',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: OledColors.softIndigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                app.packageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: OledColors.textMuted,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
