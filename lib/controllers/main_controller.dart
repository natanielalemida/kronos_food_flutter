
class MainController {
  static final MainController _instance = MainController._internal();
  MainController._internal();
  factory MainController() {
    return _instance;
  }
  String? accessToken;
  String? refreshToken;

  void setConfig(Map<String, dynamic> config) {
    accessToken = config['accessToken'];
    refreshToken = config['refreshToken'];
  }
}
