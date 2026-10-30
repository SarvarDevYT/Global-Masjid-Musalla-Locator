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
  double _qiblaBearing = 230.0;

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

  String _getDirectionDescription(double bearing, String locale) {
    // 0 = N, 90 = E, 180 = S, 270 = W
    final b = (bearing % 360 + 360) % 360;
    if (b >= 202.5 && b < 247.5) {
      return locale == 'en'
          ? 'south-west'
          : (locale == 'ru' ? 'юго-запад' : 'janubi-g\'arb');
    } else if (b >= 157.5 && b < 202.5) {
      return locale == 'en'
          ? 'south'
          : (locale == 'ru' ? 'юг' : 'janub');
    } else if (b >= 247.5 && b < 292.5) {
      return locale == 'en'
          ? 'west'
          : (locale == 'ru' ? 'запад' : 'g\'arb');
    } else if (b >= 112.5 && b < 157.5) {
      return locale == 'en'
          ? 'south-east'
          : (locale == 'ru' ? 'юго-восток' : 'janubi-sharq');
    } else if (b >= 67.5 && b < 112.5) {
      return locale == 'en'
          ? 'east'
          : (locale == 'ru' ? 'восток' : 'sharq');
    } else if (b >= 22.5 && b < 67.5) {
      return locale == 'en'
          ? 'north-east'
          : (locale == 'ru' ? 'северо-восток' : 'shimoli-sharq');
    } else if (b >= 292.5 && b < 337.5) {
      return locale == 'en'
          ? 'north-west'
          : (locale == 'ru' ? 'северо-запад' : 'shimoli-g\'arb');
    } else {
      return locale == 'en'
          ? 'north'
          : (locale == 'ru' ? 'север' : 'shimol');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    // Qibla screen uses deep dark night palette as shown in PDF Page 4
    const bgDark = Color(0xFF061518);
    const cardDark = Color(0xFF0C2126);
    const cardBorder = Color(0xFF153940);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              AppTranslations.get('qibla_compass', locale),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              AppTranslations.get('kaba_direction', locale),
              style: const TextStyle(
                color: Color(0xFF8BA69C),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${AppTranslations.get('error_network', locale)}\n(${snapshot.error})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final double? heading = snapshot.data?.heading;

            // Mathematical calculation fixing 0°/360° boundary:
            // angleDiff = min(|h - qibla| % 360, 360 - (|h - qibla| % 360))
            final double rawDiff = heading != null ? ((heading - _qiblaBearing).abs()) % 360.0 : 180.0;
            final double angleDiff = math.min(rawDiff, 360.0 - rawDiff);
            final bool isFacingQibla = angleDiff <= 5.0;

            final String dirDesc = _getDirectionDescription(_qiblaBearing, locale);

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- COMPASS DIAL ---
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow when aligned with Qibla
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 270,
                            height: 270,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFacingQibla
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              boxShadow: isFacingQibla
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.5),
                                        blurRadius: 36,
                                        spreadRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),

                          // Compass Ring
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardDark,
                              border: Border.all(
                                color: isFacingQibla ? AppColors.primaryLight : cardBorder,
                                width: isFacingQibla ? 3.0 : 2.0,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cardinal Direction Letters (N, E, S, W)
                                const Positioned(
                                  top: 14,
                                  child: Text(
                                    'N',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  right: 16,
                                  child: Text(
                                    'E',
                                    style: TextStyle(
                                      color: Color(0xFF8BA69C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 14,
                                  child: Text(
                                    'S',
                                    style: TextStyle(
                                      color: Color(0xFF8BA69C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 16,
                                  child: Text(
                                    'W',
                                    style: TextStyle(
                                      color: Color(0xFF8BA69C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),

                                // Inner concentric ring
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isFacingQibla
                                          ? AppColors.primary.withValues(alpha: 0.4)
                                          : cardBorder.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                ),

                                // Rotating Qibla Needle
                                Transform.rotate(
                                  angle: heading != null
                                      ? ((_qiblaBearing - heading) * (math.pi / 180.0))
                                      : (_qiblaBearing * (math.pi / 180.0)),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Gold/Emerald needle pointer pointing upwards
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.navigation,
                                            size: 58,
                                            color: isFacingQibla ? AppColors.primaryLight : AppColors.gold,
                                          ),
                                          const SizedBox(height: 50),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Center Pivot Circle with Ka'ba Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isFacingQibla
                                        ? AppColors.emeraldGradient
                                        : AppColors.goldGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.mosque, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- DIGITAL ANGLE DISPLAY ---
                    Text(
                      '${_qiblaBearing.round()}°',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: isFacingQibla ? AppColors.primaryLight : AppColors.goldLight,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppTranslations.get('qibla_heading_title', locale)} · $dirDesc',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8BA69C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // --- INSTRUCTIONS CARD ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFacingQibla
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isFacingQibla ? Icons.check_circle : Icons.screen_rotation_outlined,
                            color: isFacingQibla ? AppColors.primaryLight : AppColors.gold,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              AppTranslations.get('qibla_compass_instructions', locale),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFF1F7F4),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
