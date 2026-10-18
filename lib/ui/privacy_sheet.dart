import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_logs_provider.dart';
import '../providers/settings_provider.dart';
import 'theme/oled_theme.dart';

class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) =>
            PrivacySheetContent(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PrivacySheetContent extends ConsumerWidget {
  final ScrollController scrollController;

  const PrivacySheetContent({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(appStringsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      controller: scrollController,
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OledColors.calmTeal.withValues(alpha: 0.15),
                border: Border.all(
                  color: OledColors.calmTeal.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: OledColors.calmTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr(
                      fr: 'Confidentialité & RGPD (Belgique)',
                      nl: 'Privacy & AVG / GDPR (België)',
                      de: 'Datenschutz & DSGVO (Belgien)',
                      es: 'Privacidad y RGPD (Bélgica)',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OledColors.textPrimary,
                    ),
                  ),
                  Text(
                    s.tr(
                      fr: 'Règlement (UE) 2016/679 & Loi belge du 30 juillet 2018',
                      nl: 'Verordening (EU) 2016/679 & Belgische wet van 30 juli 2018',
                      de: 'EU-DSGVO 2016/679 & Belgisches Gesetz vom 30. Juli 2018',
                      es: 'Reglamento (UE) 2016/679 y Ley belga del 30 de julio de 2018',
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
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
        const SizedBox(height: 16),

        // 1. Biometrics 100% Local Guarantee (Art. 9 RGPD)
        _PrivacySectionCard(
          icon: Icons.favorite_border_rounded,
          accent: OledColors.warmAmber,
          badge: 'Art. 9 RGPD • 100% Local',
          title: s.tr(
            fr: 'Données biométriques & santé : 100 % sur ton téléphone',
            nl: 'Biometrische & gezondheidsgegevens: 100% op je telefoon',
            de: 'Biometrie- & Gesundheitsdaten: 100 % lokal auf dem Gerät',
            es: 'Datos biométricos y de salud: 100 % en tu teléfono',
          ),
          body: s.tr(
            fr: 'Conformément à l\'article 9 du RGPD et au Titre 1er de la Loi belge du 30 juillet 2018, SleepStop ne collecte, ne transmet et ne stocke AUCUNE donnée de santé sur un serveur.\n'
                '• Ton pouls (BPM), tes intervalles R-R (HRV) et ta courbe de sommeil sont traités en temps réel en mémoire vive et sauvegardés uniquement dans le stockage privé de ton téléphone.\n'
                '• Les titres des livres audio ou vidéos que tu écoutes ne quittent jamais ton appareil.',
            nl: 'Overeenkomstig artikel 9 van de AVG (GDPR) en de Belgische wet van 30 juli 2018 verzamelt, verzendt of bewaart SleepStop GEEN gezondheidsgegevens op een server.\n'
                '• Je hartslag (BPM), R-R-intervallen (HRV) en slaapcurve worden uitsluitend lokaal op je toestel verwerkt en bewaard.\n'
                '• Titels van luisterboeken of video\'s verlaten nooit je telefoon.',
            de: 'Gemäß Artikel 9 DSGVO und dem belgischen Datenschutzgesetz vom 30. Juli 2018 erhebt oder speichert SleepStop KEINE Gesundheitsdaten auf Servern.\n'
                '• Deine Herzfrequenz (BPM), R-R-Intervalle (HRV) und Schlafkurve bleiben zu 100 % lokal auf deinem Smartphone.\n'
                '• Hörbuch- oder Videotitel verlassen niemals dein Gerät.',
            es: 'Conforme al artículo 9 del RGPD y la Ley belga del 30 de julio de 2018, SleepStop NO recopila ni almacena ningún dato de salud en servidores.\n'
                '• Tu pulso (BPM), intervalos R-R (HRV) y curva de sueño permanecen 100 % en tu teléfono.\n'
                '• Los títulos de tus audiolibros o vídeos nunca salen de tu dispositivo.',
          ),
        ),
        const SizedBox(height: 12),

        // 2. Anonymous Telemetry Toggle (Hosted in Saint-Ghislain, Belgium)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OledColors.elevatedSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: settings.anonymousTelemetryEnabled
                  ? OledColors.calmTeal.withValues(alpha: 0.45)
                  : OledColors.subtleBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: OledColors.calmTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.tr(
                        fr: 'Statistiques anonymes (Hébergées en Belgique 🇧🇪)',
                        nl: 'Anonieme statistieken (Gehost in België 🇧🇪)',
                        de: 'Anonyme Statistiken (Gehostet in Belgien 🇧🇪)',
                        es: 'Estadísticas anónimas (Alojadas en Bélgica 🇧🇪)',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: OledColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.tr(
                  fr: 'Pour nous aider à améliorer l\'application, SleepStop incrémente des compteurs globaux strictement anonymes (nombre de sessions lancées, mode Montre/Téléphone, langue FR/NL/DE/ES) hébergés dans le centre de données européen de Saint-Ghislain (Belgique - europe-west1). Aucun identifiant publicitaire, ni IP, ni compte, ni BPM n\'est transmis.',
                  nl: 'Om de app te verbeteren houdt SleepStop strikt anonieme tellers bij (aantal sessies, Horloge/Telefoon-modus, taal FR/NL/DE/ES), gehost in het Europese datacenter in Saint-Ghislain (België - europe-west1). Geen reclame-ID, IP, account of BPM wordt verzonden.',
                  de: 'Zur Verbesserung der App sendet SleepStop streng anonyme Zähler (Sitzungsanzahl, Uhr/Telefon-Modus, Sprache FR/NL/DE/ES) an das europäische Rechenzentrum in Saint-Ghislain (Belgien - europe-west1). Keine Werbe-ID, kein Konto und keine BPM-Werte werden übertragen.',
                  es: 'Para mejorar la app, SleepStop incrementa contadores estrictamente anónimos (sesiones iniciadas, modo Reloj/Teléfono, idioma FR/NL/DE/ES) alojados en el centro de datos europeo de Saint-Ghislain (Bélgica - europe-west1). No se envía ningún ID publicitario, cuenta ni BPM.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: OledColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: OledColors.calmTeal,
                title: Text(
                  s.tr(
                    fr: 'Partager les compteurs techniques anonymes',
                    nl: 'Anonieme technische tellers delen',
                    de: 'Anonyme technische Zähler teilen',
                    es: 'Compartir contadores técnicos anónimos',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OledColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  settings.anonymousTelemetryEnabled
                      ? s.tr(
                          fr: 'Activé (Zéro donnée personnelle • Serveur Belgique)',
                          nl: 'Ingeschakeld (Geen persoonsgegevens • Server België)',
                          de: 'Aktiviert (Keine personenbezogenen Daten • Server Belgien)',
                          es: 'Activado (Cero datos personales • Servidor Bélgica)',
                        )
                      : s.tr(
                          fr: 'Désactivé (Aucune requête réseau statistique)',
                          nl: 'Uitgeschakeld (Geen statistisch netwerkverkeer)',
                          de: 'Deaktiviert (Keine statistischen Netzwerkanfragen)',
                          es: 'Desactivado (Sin peticiones de red estadísticas)',
                        ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OledColors.textSecondary,
                  ),
                ),
                value: settings.anonymousTelemetryEnabled,
                onChanged: notifier.setAnonymousTelemetryEnabled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Belgian Data Protection Authority (APD / GBA)
        _PrivacySectionCard(
          icon: Icons.account_balance_rounded,
          accent: OledColors.softIndigo,
          badge: 'APD / GBA • Bruxelles',
          title: s.tr(
            fr: 'Juridiction Belge & Autorité de Protection des Données',
            nl: 'Belgische Jurisdictie & Gegevensbeschermingsautoriteit (GBA)',
            de: 'Belgische Gerichtsbarkeit & Datenschutzbehörde (APD/GBA)',
            es: 'Jurisdicción Belga y Autoridad de Protección de Datos (APD)',
          ),
          body: s.tr(
            fr: 'Responsable du traitement : SleepStop (Belgique) — Droit applicable : Droit belge (Livre XII du Code de droit économique & Loi du 30 juillet 2018).\n'
                'Autorité de contrôle compétente en Belgique :\n'
                '• Autorité de protection des données (APD / GBA)\n'
                '• Rue de la Presse 35, 1000 Bruxelles (Belgique)\n'
                '• Tél : +32 (0)2 274 48 00 • contact@apd-gba.be\n'
                '• Site : www.autoriteprotectiondonnees.be',
            nl: 'Verwerkingsverantwoordelijke: SleepStop (België) — Toepasselijk recht: Belgisch recht (Boek XII WER & Wet van 30 juli 2018).\n'
                'Bevoegde toezichthoudende autoriteit in België:\n'
                '• Gegevensbeschermingsautoriteit (GBA / APD)\n'
                '• Drukpersstraat 35, 1000 Brussel (België)\n'
                '• Tel: +32 (0)2 274 48 00 • contact@apd-gba.be\n'
                '• Website: www.gegevensbeschermingsautoriteit.be',
            de: 'Verantwortlicher: SleepStop (Belgien) — Anwendbares Recht: Belgisches Recht (Gesetz vom 30. Juli 2018).\n'
                'Zuständige Aufsichtsbehörde in Belgien:\n'
                '• Autorité de protection des données / Gegevensbeschermingsautoriteit (APD/GBA)\n'
                '• Rue de la Presse 35 / Drukpersstraat 35, 1000 Brüssel (Belgien)\n'
                '• Tel.: +32 (0)2 274 48 00 • contact@apd-gba.be',
            es: 'Responsable del tratamiento: SleepStop (Bélgica) — Legislación aplicable: Derecho belga (Ley del 30 de julio de 2018).\n'
                'Autoridad de control competente en Bélgica:\n'
                '• Autorité de protection des données (APD / GBA)\n'
                '• Rue de la Presse 35, 1000 Bruselas (Bélgica)\n'
                '• Tel.: +32 (0)2 274 48 00 • contact@apd-gba.be',
          ),
        ),
        const SizedBox(height: 14),

        // 4. Actions: Copy Online Policy URL & Art. 17 Immediate Erasure
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: 'https://sleepstop-eu.web.app/privacy',
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.tr(
                          fr: 'Lien copiée : https://sleepstop-eu.web.app/privacy',
                          nl: 'Link gekopieerd: https://sleepstop-eu.web.app/privacy',
                          de: 'Link kopiert: https://sleepstop-eu.web.app/privacy',
                          es: 'Enlace copiado: https://sleepstop-eu.web.app/privacy',
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 17),
                label: Text(
                  s.tr(
                    fr: 'Charte web complète',
                    nl: 'Volledig webbeleid',
                    de: 'Online-Richtlinie',
                    es: 'Política web',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OledColors.calmTeal,
                  side: BorderSide(
                    color: OledColors.calmTeal.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(sessionLogsProvider.notifier)
                      .clearAllLogs();
                  await notifier.resetAllSettingsAndLearnedData();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.tr(
                          fr: 'Toutes tes données locales ont été effacées (Art. 17 RGPD).',
                          nl: 'Al je lokale gegevens zijn gewist (Art. 17 AVG).',
                          de: 'Alle lokalen Daten wurden gelöscht (Art. 17 DSGVO).',
                          es: 'Todos tus datos locales han sido borrados (Art. 17 RGPD).',
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 17),
                label: Text(
                  s.tr(
                    fr: 'Effacer mes données',
                    nl: 'Wis mijn gegevens',
                    de: 'Daten löschen',
                    es: 'Borrar mis datos',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OledColors.mutedRose,
                  side: BorderSide(
                    color: OledColors.mutedRose.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacySectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String badge;
  final String title;
  final String body;

  const _PrivacySectionCard({
    required this.icon,
    required this.accent,
    required this.badge,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OledColors.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: OledColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: OledColors.textSecondary,
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}
