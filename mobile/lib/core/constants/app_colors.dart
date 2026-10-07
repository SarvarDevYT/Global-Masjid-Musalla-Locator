import 'package:flutter/material.dart';

class AppColors {
  // --- Asl Islomiy Zumrad Yashil Palitrasi (Royal Islamic Emerald) ---
  static const Color primary = Color(0xFF047857); // Deep Royal Emerald Green
  static const Color primaryLight = Color(0xFF10B981); // Bright Malachite
  static const Color primaryDark = Color(0xFF064E3B); // Deep Forest Night
  static const Color primarySurface = Color(0xFFECFDF5); // Soft Mint Silk

  // --- Islomiy Oltin va Saroy Zardo'zligi (Imperial Islamic Gold) ---
  static const Color gold = Color(0xFFD4AF37); // Classic Pure Islamic Gold
  static const Color goldLight = Color(0xFFFDE68A); // Bright Warm Gold
  static const Color goldDark = Color(0xFFB78B1E); // Antique Bronze Gold
  static const Color accentGold = Color(0xFFD4AF37); // Backward compatible
  static const Color accentGoldLight = Color(0xFFFBBF24); // Backward compatible

  // --- Yorug' rejim (Light Theme - Sof oq va ipak ohanglari) ---
  static const Color lightBg = Color(0xFFF8FAF8);
  static const Color lightCard = Colors.white;
  static const Color lightCardBorder = Color(0xFFE2EBE5);
  static const Color lightTextPrimary = Color(0xFF0A2218);
  static const Color lightTextSecondary = Color(0xFF4B6358);

  // --- Qorong'i rejim (Dark Theme - Ka'ba kechasi va moviy zumrad) ---
  static const Color darkBg = Color(0xFF061517);
  static const Color darkCard = Color(0xFF0B2125);
  static const Color darkCardBorder = Color(0xFF153940);
  static const Color darkTextPrimary = Color(0xFFF1F7F4);
  static const Color darkTextSecondary = Color(0xFF8BA69C);

  // --- Holatlar va belgilashlar (Status & Tags) ---
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF0284C7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // --- Islomiy Gradiyentlar (Islamic Gradients) ---
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF044332), Color(0xFF065F46), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB78B1E), Color(0xFFD4AF37), Color(0xFFFDE68A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF0E272C), Color(0xFF08191C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F9F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
