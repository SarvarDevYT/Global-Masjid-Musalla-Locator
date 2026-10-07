import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/locale_provider.dart';
import '../../providers/mosque_providers.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  double _qiblaBearing = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateQibla();
  }

  void _calculateQibla() {
    final locationAsync = ref.read(userLocationProvider);
    final LatLng loc = locationAsync.value ?? const LatLng(41.3381, 69.2415);
    _qiblaBearing = GeoUtils.calculateQiblaBearing(loc.latitude, loc.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          AppTranslations.get('qibla_compass', locale),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Sensor xatosi: ${snapshot.error}'),
              );
            }

            final double? heading = snapshot.data?.heading;
            final double diff = heading != null ? ((heading - _qiblaBearing).abs()) % 360 : 180.0;
            final bool isFacingQibla = diff < 4.0 || diff > 356.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Info Card (Islamic Gold & Emerald)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isFacingQibla
                            ? AppColors.gold
                            : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        width: isFacingQibla ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isFacingQibla ? AppColors.gold : AppColors.primary)
                              .withValues(alpha: isDark ? 0.25 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.mosque, size: 14, color: AppColors.gold),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Qibla (Ka\'ba)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_qiblaBearing.round()}°',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 38,
                              width: 1,
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.explore, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kompas',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  heading != null ? '${heading.round()}°' : '---',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isFacingQibla ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isFacingQibla) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.black87),
                                SizedBox(width: 6),
                                Text(
                                  '✨ Qiblaga to\'g\'rilandi! (Ka\'ba tomoni)',
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Islamic Astrolabe Compass Dial
                  Center(
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Astrolabe Gold Ring Aura
                          Container(
                            width: 290,
                            height: 290,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isFacingQibla ? AppColors.gold : AppColors.primary).withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          // Compass Base Rotating Dial
                          Transform.rotate(
                            angle: heading != null ? -((heading * math.pi) / 180) : 0,
                            child: Container(
                              width: 270,
                              height: 270,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkCard : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isFacingQibla ? AppColors.gold : AppColors.primary).withValues(alpha: 0.2),
                                    blurRadius: 28,
                                    spreadRadius: 3,
                                  ),
                                ],
                                border: Border.all(
                                  color: isFacingQibla ? AppColors.gold : AppColors.primary.withValues(alpha: 0.4),
                                  width: 4,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // N, E, S, W labels
                                  const Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text(
                                        'N',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text(
                                        'S',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text(
                                        'W',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Text(
                                        'E',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),

                                  // Ka'bah indicator on dial ring (Gold Crescent & Mosque badge)
                                  Transform.rotate(
                                    angle: (_qiblaBearing * math.pi) / 180,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.goldGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(alpha: 0.6),
                                              blurRadius: 10,
                                            ),
                                          ],
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.mosque, size: 18, color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center Ka'bah Direction Pointer
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: isFacingQibla ? AppColors.goldGradient : AppColors.emeraldGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: (isFacingQibla ? AppColors.gold : AppColors.primary).withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.navigation,
                              color: isFacingQibla ? Colors.black87 : Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Calibration note with Islamic crescent icon
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard.withValues(alpha: 0.6) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.screen_rotation_alt, color: AppColors.gold, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppTranslations.get('calibrate_compass', locale),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
