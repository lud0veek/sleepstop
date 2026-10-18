import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/sleep_settings.dart';
import '../providers/settings_provider.dart';
import '../services/permission_service.dart';
import 'theme/oled_theme.dart';
import 'watch_guide_sheet.dart';
import 'widgets/flag_icon.dart';

/// Four-page introduction shown on the very first launch (and again from
/// Settings → "Replay the introduction"). The last page doubles as the
/// permission explainer: "Allow & start" triggers the system prompts.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;

  static const int _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish(requestPermissions: true);
    }
  }

  Future<void> _finish({required bool requestPermissions}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final notifier = ref.read(settingsProvider.notifier);
    if (requestPermissions) {
      await notifier.markOnboardingPermissionsShown();
      await PermissionService.instance.requestAllRequiredPermissions();
      await PermissionService.instance.requestOverlayPermissionIfMissing();
    }
    await notifier.markOnboardingCompleted();
    // The root widget swaps to HomeScreen as soon as the flag flips.
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final settings = ref.watch(settingsProvider);
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: OledColors.trueBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: language + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  _LanguagePill(
                    current: settings.languageCode,
                    onSelected: (code) => ref
                        .read(settingsProvider.notifier)
                        .setLanguageCode(code),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _finish(requestPermissions: false),
                      child: Text(
                        s.onbSkip,
                        style: const TextStyle(
                          color: OledColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _PromisePage(s: s),
                  _ModePage(s: s, settings: settings, ref: ref),
                  _NightPage(s: s),
                  _PermissionsPage(s: s),
                ],
              ),
            ),
            // Bottom: dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  _Dots(count: _pageCount, index: _page),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: OledColors.warmAmber,
                        foregroundColor: OledColors.trueBlack,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: OledColors.trueBlack,
                              ),
                            )
                          : Text(
                              isLast ? s.onbAllowAndStart : s.onbNext,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (isLast) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _finish(requestPermissions: false),
                      child: Text(
                        s.permNotNow,
                        style: const TextStyle(
                          color: OledColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

class _PromisePage extends StatelessWidget {
  final AppStrings s;
  const _PromisePage({required this.s});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      hero: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: OledColors.warmAmber.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: OledColors.warmAmber.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Image.asset(
            'assets/icon/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.nights_stay_rounded,
              color: OledColors.warmAmber,
              size: 56,
            ),
          ),
        ),
      ),
      title: s.onbPromiseTitle,
      body: s.onbPromiseBody,
      children: [
        _Bullet(
          icon: Icons.watch_rounded,
          color: OledColors.softIndigo,
          text: s.onbPromiseBullet1,
        ),
        _Bullet(
          icon: Icons.lock_outline_rounded,
          color: OledColors.calmTeal,
          text: s.onbPromiseBullet2,
        ),
        _Bullet(
          icon: Icons.wb_twilight_rounded,
          color: OledColors.warmAmber,
          text: s.onbPromiseBullet3,
        ),
      ],
    );
  }
}

class _ModePage extends StatelessWidget {
  final AppStrings s;
  final SleepSettings settings;
  final WidgetRef ref;
  const _ModePage({required this.s, required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final mode = settings.preferredMode;
    return _PageScaffold(
      title: s.onbModeTitle,
      body: s.onbModeBody,
      children: [
        _ModeCard(
          selected: mode == DetectionMode.watchBle,
          icon: Icons.watch_rounded,
          accent: OledColors.softIndigo,
          title: s.onbModeWatchTitle,
          body: s.onbModeWatchBody,
          badge: s.onbRecommended,
          onTap: () => ref
              .read(settingsProvider.notifier)
              .setPreferredMode(DetectionMode.watchBle),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          selected: mode == DetectionMode.phoneFadeShake,
          icon: Icons.vibration_rounded,
          accent: OledColors.warmAmber,
          title: s.onbModePhoneTitle,
          body: s.onbModePhoneBody,
          onTap: () => ref
              .read(settingsProvider.notifier)
              .setPreferredMode(DetectionMode.phoneFadeShake),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () => WatchGuideSheet.show(context),
            icon: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: OledColors.calmTeal,
            ),
            label: Text(
              s.onbWatchHowTo,
              style: const TextStyle(
                color: OledColors.calmTeal,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NightPage extends StatelessWidget {
  final AppStrings s;
  const _NightPage({required this.s});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: s.onbNightTitle,
      body: s.onbNightBody,
      children: [
        _Step(
          index: 1,
          icon: Icons.bedtime_rounded,
          title: s.onbNightStep1Title,
          body: s.onbNightStep1Body,
        ),
        _Step(
          index: 2,
          icon: Icons.graphic_eq_rounded,
          title: s.onbNightStep2Title,
          body: s.onbNightStep2Body,
        ),
        _Step(
          index: 3,
          icon: Icons.replay_rounded,
          title: s.onbNightStep3Title,
          body: s.onbNightStep3Body,
        ),
      ],
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  final AppStrings s;
  const _PermissionsPage({required this.s});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: s.permTitle,
      body: s.permIntro,
      children: [
        _Bullet(
          icon: Icons.bluetooth_searching_rounded,
          color: OledColors.softIndigo,
          title: s.permBluetoothTitle,
          text: s.permBluetoothBody,
        ),
        _Bullet(
          icon: Icons.notifications_active_outlined,
          color: OledColors.warmAmber,
          title: s.permNotifTitle,
          text: s.permNotifBody,
        ),
        _Bullet(
          icon: Icons.battery_saver_rounded,
          color: OledColors.calmTeal,
          title: s.permBatteryTitle,
          text: s.permBatteryBody,
        ),
        _Bullet(
          icon: Icons.brightness_2_rounded,
          color: OledColors.textSecondary,
          title: '${s.overlayPermTitle} • ${s.overlayPermOptional}',
          text: s.overlayPermBody,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class _PageScaffold extends StatelessWidget {
  final Widget? hero;
  final String title;
  final String body;
  final List<Widget> children;

  const _PageScaffold({
    this.hero,
    required this.title,
    required this.body,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hero != null) ...[
            const SizedBox(height: 18),
            Center(child: hero),
            const SizedBox(height: 30),
          ] else
            const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: OledColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: OledColors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          ...children,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? title;
  final String text;

  const _Bullet({
    required this.icon,
    required this.color,
    this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: OledColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Padding(
                  padding: EdgeInsets.only(top: title == null ? 9 : 0),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: title == null ? 14.5 : 13,
                      height: 1.4,
                      color: title == null
                          ? OledColors.textPrimary
                          : OledColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String body;

  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OledColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OledColors.subtleBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OledColors.warmAmber.withValues(alpha: 0.16),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: OledColors.warmAmber,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: OledColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: OledColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: OledColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : OledColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.7)
                  : OledColors.subtleBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: OledColors.textPrimary,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: OledColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : OledColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? OledColors.warmAmber : OledColors.subtleBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _LanguagePill({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'FR / NL / DE / ES',
      color: OledColors.elevatedSurface,
      onSelected: onSelected,
      itemBuilder: (_) => AppStrings.supportedLanguages
          .map(
            (code) => PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  FlagIcon(code: code, width: 22),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.languageName(code),
                    style: TextStyle(
                      fontWeight: code == current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: code == current
                          ? OledColors.warmAmber
                          : OledColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: OledColors.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OledColors.subtleBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagIcon(code: current, width: 18),
            const SizedBox(width: 7),
            Text(
              current.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: OledColors.warmAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
