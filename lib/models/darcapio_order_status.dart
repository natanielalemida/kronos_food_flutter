/// Etapas de operação; mantém os códigos recebidos do ERP compatíveis com pedidos antigos.
String darcapioOrderStage(String status) => switch (status) {
      'aguardando_erp' || 'recebido_erp' => 'aguardando_aceite',
      'aceito' => 'em_preparo',
      'pronto_retirada' || 'pronto_entrega' => 'pronto',
      'saiu_para_entrega' => 'em_rota_entrega',
      _ => status,
    };

String darcapioStatusLabel(String status) =>
    switch (darcapioOrderStage(status)) {
      'aguardando_aceite' => 'Aguardando aceite',
      'em_preparo' => 'Em preparo',
      'pronto' => 'Pronto',
      'em_rota_entrega' => 'Em rota de entrega',
      'concluido' => 'Concluído',
      'cancelado' => 'Cancelado',
      _ => status,
    };
