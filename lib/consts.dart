import 'package:flutter/material.dart';

class Consts {
  // API URLs
  static const primaryColor = Color(4278217322);
  static const String baseUrl = "https://merchant-api.ifood.com.br";
  static const String authUrl =
      "https://merchant-api.ifood.com.br/authentication/v1.0";
  static const String eventsUrl =
      "https://merchant-api.ifood.com.br/events/v1.0";

  // Authentication
  // static const String clientId = "7ff46aa1-3276-4fc4-8f7e-61458c72eb50";
  // static const String clientSecret =
  //     "101ft61m1624i2ssnoc33gphah3rr3mj4n9n5fjrglwrtu7drfp5piug3rr5uyk92qgan01tn3qwhvmg7q7h7yj8scfik45jic55";
  //Authentication - Prod
  static const String clientId = "30c1f323-c4a1-4c96-9066-3cf5e9519781";
  static const String clientSecret =
      "ent3fguwdx2k7kub3xywdw4pxd21g2lfiyj3i13pnnk32scooa5s3pexlcp17i9xafid5ytyzq7ee52j5pwiwvfa4hmje87up8u";
  // static const String username = "seu_usuario_ifood";
  // static const String password = "sua_senha_ifood";

  // HTTP Headers
  static const Map<String, String> jsonHeaders = {
    'Content-type': 'application/json',
  };

  // SharedPreferences Keys
  // static const String pedidosKey = 'pedidos_data';
  // static const String pedidosIdsKey = 'pedidos_ids';
  // static const String lastCleanupKey = 'last_cleanup';
  // static const String tokenExpirationKey = 'expiration_time';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String kronosTokenKey = 'kronos_token';
  static const String configKey = 'config';
  static const String expirationTimeKey = 'expiration_time';
  static const String serverIpKey = 'server_ip';
  static const String codCaixa = 'cod_caixa';
  static const String companyCodeKey = 'company_code';
  static const String terminalCodeKey = 'terminal_code';
  static const String usernameKey = 'username';
  static const String passwordKey = 'password';

  // Time Constants
  // static const int orderExpirationHours = 8; // Orders expire after 8 hours
  // static const int cleanupIntervalHours = 8; // Cleanup runs every 12 hours
  static const int pollingIntervalSeconds =
      30; // Poll for new events every 30 seconds
  static const int tokenRefreshMarginMinutes =
      1; // Refresh token 1 minute before expiration

  // Date Range Constants
  // static const int historicDataYears = 5; // Consider data from the past 5 years
  // static const int futureDataYears = 1; // Consider data up to next year

  // Order Status Codes
  static const String statusPlaced = 'PLC';
  static const String statusConfirmed = 'CFM';
  static const String statusDispatched = 'DSP';
  static const String statusConcluded = 'CON';
  static const String statusCancelled = 'CAN';
  // static const String statusDriverDeclined = 'DDCR';

  // Event Group Constants
  static const String orderStatusGroup = "ORDER_STATUS";
}
