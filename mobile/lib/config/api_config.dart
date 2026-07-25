/// API 配置
///
/// 默认连接 Android 模拟器的宿主机地址 (10.0.2.2)。
/// 构建时可通过 --dart-define 覆盖：
///   flutter run --dart-define=API_HOST=192.168.2.141 --dart-define=API_PORT=8080
class ApiConfig {
  static const String _defaultHost = '10.0.2.2';
  static const String _defaultPort = '8080';

  static String get baseUrl {
    final host = const String.fromEnvironment('API_HOST',
        defaultValue: _defaultHost);
    final port = const String.fromEnvironment('API_PORT',
        defaultValue: _defaultPort);
    return 'http://$host:$port';
  }

  static String get apiV1 => '$baseUrl/api/v1';
}
