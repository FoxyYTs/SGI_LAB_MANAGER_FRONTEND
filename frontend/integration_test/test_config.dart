const String kServerUrl =
    String.fromEnvironment('SERVER_URL', defaultValue: 'https://dev-apisgi.foxyyts.qzz.io');
const String kTestUser =
    String.fromEnvironment('TEST_USER', defaultValue: '');
const String kTestPassword =
    String.fromEnvironment('TEST_PASSWORD', defaultValue: '');

/// Espera inicial para que la pantalla de login se renderice.
const Duration kUiReady = Duration(seconds: 3);

/// Tiempo máximo para respuestas de red (login, carga de lista).
const Duration kNetworkTimeout = Duration(seconds: 15);

/// Pausa breve entre acciones de UI.
const Duration kAnimationDelay = Duration(milliseconds: 600);
