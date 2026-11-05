import 'package:flutter/material.dart';

class ChatThemeOption {
  final String id;
  final String name;
  final Color primaryColor;
  final LinearGradient? gradient;
  final Color textColor;

  const ChatThemeOption({
    required this.id,
    required this.name,
    required this.primaryColor,
    this.gradient,
    this.textColor = Colors.white,
  });
}

class ChatThemes {
  static const ChatThemeOption blue = ChatThemeOption(
    id: 'blue',
    name: 'Xanh dương',
    primaryColor: Color(0xFF2563EB),
    gradient: LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const ChatThemeOption purple = ChatThemeOption(
    id: 'purple',
    name: 'Hồng tím',
    primaryColor: Color(0xFF8B5CF6),
    gradient: LinearGradient(
      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const ChatThemeOption sunset = ChatThemeOption(
    id: 'sunset',
    name: 'Hoàng hôn',
    primaryColor: Color(0xFFEF4444),
    gradient: LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const ChatThemeOption midnight = ChatThemeOption(
    id: 'midnight',
    name: 'Midnight',
    primaryColor: Color(0xFF4338CA),
    gradient: LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const ChatThemeOption emerald = ChatThemeOption(
    id: 'emerald',
    name: 'Ngọc lục bảo',
    primaryColor: Color(0xFF10B981),
    gradient: LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF0D9488)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const List<ChatThemeOption> all = [
    blue,
    purple,
    sunset,
    midnight,
    emerald,
  ];

  static const ChatThemeOption defaultTheme = blue;

  static ChatThemeOption findById(String? id) {
    if (id == null) return defaultTheme;
    return all.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
  }
}
