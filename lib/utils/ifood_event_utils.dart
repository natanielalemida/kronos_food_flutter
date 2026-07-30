class IfoodEventUtils {
  static const Set<String> readyEvents = {
    'RTP',
    'READY',
    'READY_FOR_PICKUP',
    'READY_FOR_DELIVERY',
    'READY_TO_PICKUP',
    'WAITING_DRIVER',
    'WAITING_FOR_DRIVER',
    'WAITING_DELIVERY',
    'SEPARATION_ENDED',
    'PREPARATION_ENDED',
    'PREPARATION_FINISHED',
  };

  static const Set<String> waitingDriverEvents = {
    'ASSIGN_DRIVER',
    'GOING_TO_ORIGIN',
    'ARRIVED_AT_ORIGIN',
    'DELIVERY_GROUP_ASSIGNED',
  };

  static const Set<String> inRouteEvents = {
    'DSP',
    'DISPATCHED',
    'IN_DELIVERY',
    'IN_ROUTE',
    'ON_ROUTE',
    'GOING_TO_DESTINATION',
    'COLLECTED',
    'ARRIVED_AT_DESTINATION',
    'DELIVERY_RETURNING_TO_ORIGIN',
    'DELIVERY_RETURNED_TO_ORIGIN',
    'DELIVERY_RETURN_CODE_REQUESTED',
  };

  static const Set<String> informationalEvents = {
    'ORDER_PATCHED',
    'DELIVERY_ADDRESS_CHANGE',
    'DELIVERY_PHONE_CHANGE',
    'DDCR',
    'DELIVERY_DROP_CODE_REQUESTED',
    'RECOMMENDED_PREPARATION_START',
  };

  static const Set<String> finishedEvents = {
    'CON',
    'CONCLUDED',
    'DELIVERED',
    'DELIVERY_DELIVERED',
    'DELIVERY_COMPLETED',
    'DELIVERY_FINISHED',
    'COMPLETED',
    'ORDER_DELIVERED',
    'CAN',
    'CANCELLED',
    'ORDER_CANCELLED',
  };

  static String normalize(String code) => code.trim().toUpperCase();

  static bool isReadyEvent(String code) =>
      readyEvents.contains(normalize(code));

  static bool isWaitingDriverEvent(String code) =>
      waitingDriverEvents.contains(normalize(code));

  static bool isInRouteEvent(String code) =>
      inRouteEvents.contains(normalize(code));

  static bool isLogisticEvent(String code) =>
      isWaitingDriverEvent(code) || isInRouteEvent(code);

  static bool isInformationalEvent(String code) =>
      informationalEvents.contains(normalize(code));

  static bool isFinishedEvent(String code) =>
      finishedEvents.contains(normalize(code));

  static bool isIfoodDelivery(String deliveredBy) =>
      normalize(deliveredBy) == 'IFOOD';

  static bool isMerchantDelivery(String deliveredBy) =>
      normalize(deliveredBy) == 'MERCHANT';

  static bool isIfoodSalesChannel(String salesChannel) =>
      normalize(salesChannel).contains('IFOOD');

  static String readyLabel(String deliveredBy, String orderType) {
    if (isIfoodDelivery(deliveredBy)) return 'Aguardando Entregador iFood';
    if (isMerchantDelivery(deliveredBy)) return 'Pronto para entrega propria';
    if (normalize(orderType) == 'TAKEOUT') return 'Pronto para retirada';
    return 'Pedido pronto';
  }

  static String eventTitle(String code,
      {String deliveredBy = '', String orderType = ''}) {
    switch (normalize(code)) {
      case 'PLC':
      case 'PLACED':
        return 'Pedido Recebido';
      case 'CFM':
      case 'CONFIRMED':
        return 'Pedido Confirmado';
      case 'SEPARATION_STARTED':
      case 'PREPARATION_STARTED':
      case 'STP':
        return 'Preparo Iniciado';
      case 'RTP':
      case 'READY_TO_PICKUP':
      case 'SEPARATION_ENDED':
      case 'PREPARATION_ENDED':
        return readyLabel(deliveredBy, orderType);
      case 'ASSIGN_DRIVER':
        return 'Entregador iFood atribuido';
      case 'GOING_TO_ORIGIN':
        return 'Entregador indo para loja';
      case 'ARRIVED_AT_ORIGIN':
        return 'Entregador chegou na loja';
      case 'DELIVERY_GROUP_ASSIGNED':
        return 'Entrega agrupada pelo iFood';
      case 'DSP':
      case 'DISPATCHED':
        return isIfoodDelivery(deliveredBy)
            ? 'Pedido saiu com iFood'
            : 'Pedido despachado';
      case 'COLLECTED':
        return 'Pedido coletado pelo iFood';
      case 'ARRIVED_AT_DESTINATION':
        return 'Entregador chegou ao cliente';
      case 'DELIVERY_RETURNING_TO_ORIGIN':
        return 'Entregador retornando a loja';
      case 'DELIVERY_RETURNED_TO_ORIGIN':
        return 'Pedido retornou a loja';
      case 'DELIVERY_RETURN_CODE_REQUESTED':
        return 'Codigo de retorno solicitado';
      case 'DDCR':
      case 'DELIVERY_DROP_CODE_REQUESTED':
        return 'Codigo de coleta solicitado';
      case 'CON':
      case 'CONCLUDED':
        return 'Pedido Concluido';
      case 'CAN':
      case 'CANCELLED':
      case 'ORDER_CANCELLED':
        return 'Pedido Cancelado';
      case 'HSD':
      case 'HANDSHAKE_DISPUTE':
        return 'Pedido em Disputa';
      case 'HANDSHAKE_SETTLEMENT':
        return 'Disputa Resolvida';
      case 'ORDER_PATCHED':
        return 'Pedido Alterado';
      case 'DELIVERY_ADDRESS_CHANGE':
        return 'Endereco Alterado';
      case 'DELIVERY_PHONE_CHANGE':
        return 'Telefone Alterado';
      default:
        return code;
    }
  }
}
