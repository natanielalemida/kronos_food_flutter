int? parseCustomerOrderCount(Object? value) {
  final count = value is num && value.isFinite && value == value.truncate()
      ? value.toInt()
      : value is String
          ? int.tryParse(value)
          : null;
  return count != null && count >= 0 ? count : null;
}

String? customerOrderCountLabel(int? count) => count == null || count < 0
    ? null
    : '$count ${count == 1 ? 'pedido' : 'pedidos'} na loja';
