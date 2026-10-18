import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'theme/oled_theme.dart';

class WatchGuideSheet extends StatelessWidget {
  const WatchGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OledColors.cardSurface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (_, controller) =>
            WatchGuideSheetContent(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class WatchGuideSheetContent extends ConsumerWidget {
  final ScrollController scrollController;

  const WatchGuideSheetContent({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);

    final guides = [
      _WatchBrandGuide(
        brand: 'Garmin (Fenix, Forerunner, Venu, Epix, Instinct)',
        badge: '100% Native BLE',
        accent: OledColors.warmAmber,
        icon: Icons.watch_rounded,
        steps: [
          s.tr(
            fr: 'Sur la montre, maintiens le bouton Menu (milieu gauche) ou bouton bas (Venu/Vivoactive).',
            nl: 'Houd op het horloge de Menu-knop (midden-links) of onderste knop (Venu/Vivoactive) ingedrukt.',
            de: 'Halte an der Uhr die Menü-Taste (Mitte links) oder die untere Taste (Venu/Vivoactive) gedrückt.',
            es: 'En el reloj, mantén pulsado el botón Menú (centro izquierda) o el botón inferior (Venu/Vivoactive).',
          ),
          s.tr(
            fr: 'Va dans Paramètres → Capteurs et accessoires → Fréquence cardiaque au poignet.',
            nl: 'Ga naar Instellingen → Sensoren en accessoires → Polshartslag.',
            de: 'Gehe zu Einstellungen → Sensoren und Zubehör → Herzfrequenz am Handgelenk.',
            es: 'Ve a Ajustes → Sensores y accesorios → Frecuencia cardíaca en la muñeca.',
          ),
          s.tr(
            fr: 'Sélectionne « Diffuser la FC » (Broadcast Heart Rate) et appuie sur Start.',
            nl: 'Selecteer "Hartslag uitzenden" (Broadcast Heart Rate) en druk op Start.',
            de: 'Wähle „Herzfrequenz senden“ (Broadcast Heart Rate) und drücke Start.',
            es: 'Selecciona «Transmitir frecuencia cardíaca» (Broadcast Heart Rate) y pulsa Start.',
          ),
          s.tr(
            fr: 'Astuce Lit 1-clic : Configure un Raccourci bouton (Hot Key) vers « Diffuser la FC » pour l\'activer en 1 seconde le soir !',
            nl: '1-tik tip in bed: Stel een sneltoets (Hot Key) in voor "Hartslag uitzenden" om het \'s avonds in 1 seconde te starten!',
            de: '1-Klick-Bett-Tipp: Richte einen Hotkey für „HF senden“ ein, um es abends in 1 Sekunde zu aktivieren!',
            es: 'Truco de 1 clic en la cama: Configura un atajo de botón (Hot Key) hacia «Transmitir FC» para activarlo en 1 segundo.',
          ),
        ],
      ),
      _WatchBrandGuide(
        brand: 'Whoop (4.0 & 5.0)',
        badge: 'BLE Broadcast',
        accent: OledColors.calmTeal,
        icon: Icons.monitor_heart_outlined,
        steps: [
          s.tr(
            fr: 'Ouvre l\'application Whoop sur ton téléphone.',
            nl: 'Open de Whoop-app op je telefoon.',
            de: 'Öffne die Whoop-App auf deinem Smartphone.',
            es: 'Abre la aplicación Whoop en tu teléfono.',
          ),
          s.tr(
            fr: 'Appuie sur l\'icône de ton bracelet en bas à droite (Device Settings).',
            nl: 'Tik rechtsonder op het band-icoon (Device Settings).',
            de: 'Tippe unten rechts auf das Band-Symbol (Geräteeinstellungen).',
            es: 'Toca el icono de tu banda abajo a la derecha (Device Settings).',
          ),
          s.tr(
            fr: 'Active l\'option « Broadcast Heart Rate » (Diffusion FC).',
            nl: 'Schakel "Broadcast Heart Rate" (Hartslag uitzenden) in.',
            de: 'Aktiviere die Option „Broadcast Heart Rate“ (HF senden).',
            es: 'Activa la opción «Broadcast Heart Rate» (Transmitir FC).',
          ),
        ],
      ),
      _WatchBrandGuide(
        brand: 'Polar, Wahoo, Coospo, Magene (Verity Sense, H10, Tickr)',
        badge: 'Zero Config',
        accent: OledColors.softIndigo,
        icon: Icons.favorite_border_rounded,
        steps: [
          s.tr(
            fr: 'Aucune manipulation requise dans les menus !',
            nl: 'Geen menu-instellingen nodig!',
            de: 'Keine Menü-Konfiguration erforderlich!',
            es: '¡No requiere configuración en los menús!',
          ),
          s.tr(
            fr: 'Les brassards optiques (Polar Verity Sense, OH1) et ceintures émettent nativement le service standard Bluetooth 0x180D dès qu\'ils sont allumés.',
            nl: 'Optische armbanden (Polar Verity Sense, OH1) en borstbanden zenden standaard Bluetooth 0x180D uit zodra ze aan staan.',
            de: 'Optische Armbänder (Polar Verity Sense, OH1) und Brustgurte senden standardmäßig Bluetooth 0x180D, sobald sie eingeschaltet sind.',
            es: 'Los brazaletes ópticos (Polar Verity Sense, OH1) y bandas emiten nativamente Bluetooth 0x180D en cuanto se encienden.',
          ),
        ],
      ),
      _WatchBrandGuide(
        brand: 'Coros (Pace 3, Apex 2, Vertix 2)',
        badge: 'Native Toolbox',
        accent: OledColors.warmAmber,
        icon: Icons.watch_later_outlined,
        steps: [
          s.tr(
            fr: 'Maintiens le bouton Retour/Bas sur ta montre Coros pour ouvrir la Boîte à outils (Toolbox).',
            nl: 'Houd de Terug/Onder-knop op je Coros-horloge ingedrukt om de Toolbox te openen.',
            de: 'Halte die Zurück-/Unten-Taste an deiner Coros-Uhr gedrückt, um die Toolbox zu öffnen.',
            es: 'Mantén pulsado el botón Atrás/Abajo en tu reloj Coros para abrir la Caja de herramientas.',
          ),
          s.tr(
            fr: 'Tourne la molette jusqu\'à « Diffuser la FC » (Broadcast HR) et valide.',
            nl: 'Draai het wieltje naar "Hartslag uitzenden" (Broadcast HR) en bevestig.',
            de: 'Drehe die Krone auf „HF senden“ (Broadcast HR) und bestätige.',
            es: 'Gira la corona hasta «Transmitir FC» (Broadcast HR) y confirma.',
          ),
        ],
      ),
      _WatchBrandGuide(
        brand: 'Xiaomi Smart Band / Amazfit (Zepp / Mi Fitness)',
        badge: 'Zepp / Mi App',
        accent: OledColors.deepOrange,
        icon: Icons.bluetooth_audio_rounded,
        steps: [
          s.tr(
            fr: 'Ouvre l\'application Zepp (Amazfit) ou Mi Fitness (Xiaomi) sur ton téléphone.',
            nl: 'Open de Zepp- (Amazfit) of Mi Fitness-app (Xiaomi) op je telefoon.',
            de: 'Öffne die Zepp- (Amazfit) oder Mi Fitness-App (Xiaomi) auf deinem Smartphone.',
            es: 'Abre la app Zepp (Amazfit) o Mi Fitness (Xiaomi) en tu teléfono.',
          ),
          s.tr(
            fr: 'Va dans Profil → Ta montre → Partage de fréquence cardiaque Bluetooth (Activity Heart Rate Sharing) et active-le.',
            nl: 'Ga naar Profiel → Je horloge → Bluetooth-hartslag delen en schakel dit in.',
            de: 'Gehe zu Profil → Deine Uhr → Bluetooth-Herzfrequenzfreigabe und aktiviere sie.',
            es: 'Ve a Perfil → Tu reloj → Compartir frecuencia cardíaca por Bluetooth y actívalo.',
          ),
        ],
      ),
      _WatchBrandGuide(
        brand: 'Samsung Galaxy Watch / Pixel Watch (Wear OS)',
        badge: 'Wear OS App',
        accent: OledColors.softIndigo,
        icon: Icons.watch_outlined,
        steps: [
          s.tr(
            fr: 'Télécharge l\'application gratuite « Heart Rate BLE » ou « HR2VP » depuis le Play Store de ta montre Wear OS pour diffuser en BLE 0x180D.',
            nl: 'Download de gratis app "Heart Rate BLE" of "HR2VP" uit de Play Store op je Wear OS-horloge om BLE 0x180D uit te zenden.',
            de: 'Lade die kostenlose App „Heart Rate BLE“ oder „HR2VP“ im Play Store deiner Wear OS-Uhr herunter, um BLE 0x180D zu senden.',
            es: 'Descarga la app gratuita «Heart Rate BLE» o «HR2VP» desde Play Store en tu reloj Wear OS para emitir BLE 0x180D.',
          ),
          s.tr(
            fr: 'Ou utilise directement le mode « Téléphone (Secousse) » sans aucune montre !',
            nl: 'Of gebruik direct de modus "Telefoon (Schudden)" zonder horloge!',
            de: 'Oder nutze direkt den Modus „Telefon (Schütteln)“ ganz ohne Uhr!',
            es: '¡O usa directamente el modo «Teléfono (Agitar)» sin ningún reloj!',
          ),
        ],
      ),
    ];

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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OledColors.warmAmber.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: OledColors.warmAmber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.watchGuideTooltip,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OledColors.textPrimary,
                    ),
                  ),
                  Text(
                    s.tr(
                      fr: 'Comment activer le flux cardiaque temps réel (BLE 0x180D)',
                      nl: 'Hoe realtime hartslag-uitzending te activeren (BLE 0x180D)',
                      de: 'So aktivierst du den Echtzeit-Herzfrequenz-Stream (BLE 0x180D)',
                      es: 'Cómo activar la transmisión de pulso en tiempo real (BLE 0x180D)',
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
        const SizedBox(height: 18),
        ...guides.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WatchGuideCard(guide: g),
          ),
        ),
      ],
    );
  }
}

class _WatchBrandGuide {
  final String brand;
  final String badge;
  final Color accent;
  final IconData icon;
  final List<String> steps;

  const _WatchBrandGuide({
    required this.brand,
    required this.badge,
    required this.accent,
    required this.icon,
    required this.steps,
  });
}

class _WatchGuideCard extends StatelessWidget {
  final _WatchBrandGuide guide;

  const _WatchGuideCard({required this.guide});

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
              Icon(guide.icon, color: guide.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.brand,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OledColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: guide.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  guide.badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: guide.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...guide.steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: guide.accent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OledColors.textSecondary,
                        height: 1.38,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
