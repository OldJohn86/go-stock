class ApiConfig {
  // 默认连接本地 API 服务，移动端部署时改为服务器地址
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  static String baseUrl = defaultBaseUrl;

  static String get apiV1 => '$baseUrl/api/v1';
}
