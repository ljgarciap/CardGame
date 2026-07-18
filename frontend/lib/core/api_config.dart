class ApiConfig {
  // Override en dev con: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001
  // (10.0.2.2 es el loopback del host visto desde el emulador de Android)
  //
  // Puerto 8001, no 8000: en la máquina de desarrollo, 8000 está tomado
  // por factoring_backend_web (nginx de otro proyecto del workspace) —
  // ver scripts/dev-up.sh y docs/memory.md 2026-07-18.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );
}
