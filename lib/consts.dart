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
  static const String clientId = String.fromEnvironment('IFOOD_CLIENT_ID');
  static const String clientSecret =
      String.fromEnvironment('IFOOD_CLIENT_SECRET');
  static const String merchantId = String.fromEnvironment('IFOOD_MERCHANT_ID');
  static const String merchantName = String.fromEnvironment(
    'IFOOD_MERCHANT_NAME',
    defaultValue: 'Loja iFood',
  );
  static const String ifoodWidgetId =
      String.fromEnvironment('IFOOD_WIDGET_ID');

  // HTTP Headers
  static const Map<String, String> jsonHeaders = {
    'Content-type': 'application/json',
  };

  // SharedPreferences Keys
  // static const String pedidosKey = 'pedidos_data';
  // static const String pedidosIdsKey = 'pedidos_ids';
  // static const String lastCleanupKey = 'last_cleanup';
  // static const String tokenExpirationKey = 'expiration_time';
  static const String accessTokenKey = 'access_token_prod';
  static const String refreshTokenKey = 'refresh_token_prod';
  static const String kronosTokenKey = 'kronos_token';
  static const String codeUser = 'code_user';
  static const String configKey = 'config_prod';
  static const String expirationTimeKey = 'expiration_time_prod';
  static const String serverIpKey = 'server_ip';
  static const String codCaixa = 'cod_caixa';
  static const String companyCodeKey = 'company_code';
  static const String terminalCodeKey = 'terminal_code';
  static const String ifoodMerchantIdKey = 'ifood_merchant_id_prod';
  static const String ifoodWidgetIdKey = 'ifood_widget_id_prod';
  static const String kanbanModeKey = 'kanban_mode';
  static const String autoAcceptKey = 'auto_accept_prod';
  static const String autoPrintKey = 'auto_print_prod';
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
  static const String statusReadyToPickup = 'RTP';
  static const String statusDispatched = 'DSP';
  static const String statusConcluded = 'CON';
  static const String statusCancelled = 'CAN';
  static const String statusDispute = 'HSD';
  // static const String statusDriverDeclined = 'DDCR';

  // Event Group Constants
  static const String orderStatusGroup = "ORDER_STATUS";
}
