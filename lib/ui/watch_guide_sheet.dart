import 'package:flutter/material.dart';
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

class WatchGuideSheetContent extends StatelessWidget {
  final ScrollController scrollController;

  const WatchGuideSheetContent({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    const guides = [
      _WatchBrandGuide(
        brand: 'Garmin (Fenix, Forerunner, Venu, Epix, Instinct)',
        badge: '100% Native BLE',
        accent: OledColors.warmAmber,
        icon: Icons.watch_rounded,
        steps: [
          'Sur la montre, maintiens le bouton Menu (milieu gauche) ou bouton bas (Venu/Vivoactive).',
          'Va dans Paramètres → Capteurs et accessoires → Fréquence cardiaque au poignet.',
          'Sélectionne « Diffuser la FC » (Broadcast Heart Rate) et appuie sur Start.',
          'Astuce Lit 1-clic : Maintiens le bouton Light (haut gauche) ou configure un Raccourci bouton (Hot Key) vers « Diffuser la FC » pour l\'activer en 1 seconde le soir !',
        ],
      ),
      _WatchBrandGuide(
        brand: 'Whoop (4.0 & 5.0)',
        badge: 'BLE Broadcast',
        accent: OledColors.calmTeal,
        icon: Icons.monitor_heart_outlined,
        steps: [
          'Ouvre l\'application Whoop sur ton téléphone.',
          'Appuie sur l\'icône de ton bracelet en bas à droite (Device Settings).',
          'Active l\'option « Broadcast Heart Rate » (Diffusion FC).',
          'Le bracelet diffuse automatiquement en continu dès qu\'il est à ton poignet.',
        ],
      ),
      _WatchBrandGuide(
        brand: 'Polar, Wahoo, Coospo, Magene (Verity Sense, H10, Tickr)',
        badge: 'Zero Config',
        accent: OledColors.softIndigo,
        icon: Icons.favorite_border_rounded,
        steps: [
          'Aucune manipulation requise dans les menus !',
          'Les brassards optiques (Polar Verity Sense, OH1) et ceintures émettent nativement le service standard Bluetooth 0x180D dès qu\'ils sont allumés.',
          'Allume simplement le capteur et lance Start Sleep Session.',
        ],
      ),
      _WatchBrandGuide(
        brand: 'Coros (Pace 3, Apex 2, Vertix 2)',
        badge: 'Native Toolbox',
        accent: OledColors.warmAmber,
        icon: Icons.watch_later_outlined,
        steps: [
          'Maintiens le bouton Retour/Bas sur ta montre Coros pour ouvrir la Boîte à outils (Toolbox).',
          'Tourne la molette jusqu\'à « Diffuser la FC » (Broadcast HR).',
          'Valide pour démarrer l\'émission Bluetooth vers SleepStop.',
        ],
      ),
      _WatchBrandGuide(
        brand: 'Xiaomi Smart Band / Amazfit (Zepp / Mi Fitness)',
        badge: 'Via App Zepp',
        accent: OledColors.deepOrange,
        icon: Icons.bluetooth_audio_rounded,
        steps: [
          'Ouvre l\'application Zepp (Amazfit) ou Mi Fitness (Xiaomi) sur ton téléphone.',
          'Va dans Profil → Ta montre → Paramètres de santé / Partage de fréquence cardiaque.',
          'Active « Diffusion de fréquence cardiaque Bluetooth » (Activity Heart Rate Sharing).',
        ],
      ),
      _WatchBrandGuide(
        brand: 'Samsung Galaxy Watch / Pixel Watch (Wear OS)',
        badge: 'Wear OS App',
        accent: OledColors.softIndigo,
        icon: Icons.watch_outlined,
        steps: [
          'Par défaut, Wear OS garde le capteur FC en interne. Télécharge l\'application gratuite « Heart Rate BLE » ou « HR2VP » depuis le Play Store de ta montre.',
          'Lance l\'application sur ta montre au moment de te coucher : elle transforme ta Galaxy Watch / Pixel Watch en émetteur standard BLE 0x180D.',
          'Sinon, utilise le mode « Phone (Fade & Shake) » sans aucune montre !',
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guide des Montres Compatibles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OledColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Comment activer le flux cardiaque temps réel (BLE 0x180D)',
                    style: TextStyle(
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
