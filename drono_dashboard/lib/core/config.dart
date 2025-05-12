import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class Config {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  static String get apiBaseUrl => baseUrl;
  static String get wsUrl => dotenv.env['WS_URL'] ?? 'ws://localhost:8000/ws';
  
  // API Endpoints
  static String get authToken => '$baseUrl/auth/token';
  static String get devices => '$baseUrl/devices';
  static String get scanDevices => '$baseUrl/devices/scan';
  static String get commands => '$baseUrl/api/devices';
  static String get health => '$baseUrl/health';
  
  // WebSocket Channels
  static String get devicesChannel => 'devices';
  static String get alertsChannel => 'alerts';
  static String get statusChannel => 'status';
  
  // Timeouts
  static const int connectionTimeout = 15000;
  static const int receiveTimeout = 10000;
  
  // Retry Settings
  static const int maxRetries = 5;
  static const int retryDelay = 2000;
  
  // Cache Settings
  static const int cacheDuration = 300; // 5 minutes
  
  // UI Settings
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Color primaryColor = Colors.blue;