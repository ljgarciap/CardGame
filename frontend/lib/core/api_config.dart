class ApiConfig {
  // Override en dev con: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  // (10.0.2.2 es el loopback del host visto desde el emulador de Android)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
