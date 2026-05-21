// Configuration service to manage API endpoints and environment-specific settings
// This replaces hardcoded URLs with dynamic configuration

import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _defaultBaseUrl =
      'https://inneed-production.up.railway.app';
  static const String _defaultAiUrl =
      'https://in-need-production-00d5.up.railway.app';
  static const String _defaultWsUrl =
      'https://inneed-production.up.railway.app';

  // ─── Singleton Pattern ───────────────────────────────────────────────────
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  // ─── Configuration Properties ────────────────────────────────────────────
  /// Backend API base URL
  /// Set via environment variable: FLUTTER_API_URL
  /// Default: https://inneed-production.up.railway.app
  late String _baseUrl = _defaultBaseUrl;

  /// AI Service URL
  /// Set via environment variable: FLUTTER_AI_URL
  /// Default: https://in-need-production-00d5.up.railway.app
  late String _aiUrl = _defaultAiUrl;

  /// WebSocket URL
  /// Set via environment variable: FLUTTER_WS_URL
  /// Default: https://inneed-production.up.railway.app
  late String _wsUrl = _defaultWsUrl;

  // ─── Public Getters ─────────────────────────────────────────────────────

  /// Get the API base URL
  String get baseUrl => _baseUrl;

  /// Get the AI service URL
  String get aiUrl => _aiUrl;

  /// Get the WebSocket URL
  String get wsUrl => _wsUrl;

  /// Get API endpoint with path
  String endpoint(String path) => '$_baseUrl$path';

  /// Get AI endpoint with path
  String aiEndpoint(String path) => '$_aiUrl$path';

  // ─── Configuration Methods ──────────────────────────────────────────────

  /// Initialize configuration with custom URLs
  /// Used during app startup to set environment-specific values
  void initialize({
    String? baseUrl,
    String? aiUrl,
    String? wsUrl,
  }) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
    }
    if (aiUrl != null && aiUrl.isNotEmpty) {
      _aiUrl = aiUrl;
    }
    if (wsUrl != null && wsUrl.isNotEmpty) {
      _wsUrl = wsUrl;
    }

    _printConfiguration();
  }

  /// Reset configuration to defaults
  void resetToDefaults() {
    _baseUrl = _defaultBaseUrl;
    _aiUrl = _defaultAiUrl;
    _wsUrl = _defaultWsUrl;
    debugPrint('Configuration reset to defaults');
  }

  /// Print current configuration (for debugging)
  void _printConfiguration() {
    debugPrint('''
╔════════════════════════════════════════════════════════╗
║           API Configuration Initialized                ║
╠════════════════════════════════════════════════════════╣
║ Base URL:    $_baseUrl
║ AI URL:      $_aiUrl
║ WebSocket:   $_wsUrl
╚════════════════════════════════════════════════════════╝
    ''');
  }

  /// Get all configuration as a map
  Map<String, String> toMap() => {
        'baseUrl': _baseUrl,
        'aiUrl': _aiUrl,
        'wsUrl': _wsUrl,
      };
}

// ─── Global Instance ────────────────────────────────────────────────────────
/// Use this instance throughout the app
final appConfig = AppConfig();
