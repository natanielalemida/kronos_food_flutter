import 'dart:async';
import 'couriers_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../components/darcapio/order_style.dart';
import '../components/food_order_list.dart';
import '../components/darcapio/order_details.dart';
import '../components/darcapio/store_control.dart';
import '../components/darcapio/courier_dispatch_dialog.dart';
import '../components/darcapio/delivery_confirmation_dialog.dart';
import '../components/darcapio/order_conversation.dart';
import '../repositories/darcapio_repository.dart';
import '../models/food_order_entry.dart';
import '../models/pedido_model.dart';
import '../models/food_store_identity.dart';
import '../components/food_order_brand.dart';

class FoodOrdersView extends StatefulWidget {
  final DarcapioRepository? repository;
  final List<Widget> additionalActions;
  final List<PedidoModel> ifoodOrders;
  final bool ifoodLoading, ifoodConnected, kanban;
  final ValueChanged<PedidoModel>? onIfoodSelected;
  final Widget Function(PedidoModel)? ifoodDetailsBuilder;
  final Future<void> Function()? onRefreshIfood;
  final Widget? drawer;
  final String? initialOrderKey;
  const FoodOrdersView({
    super.key,
    this.repository,
    this.additionalActions = const [],
    this.ifoodOrders = const [],
    this.ifoodLoading = false,
    this.ifoodConnected = false,
    this.kanban = false,
    this.onIfoodSelected,
    this.ifoodDetailsBuilder,
    this.onRefreshIfood,
    this.drawer,
    this.initialOrderKey,
  });
  @override
  State<FoodOrdersView> createState() => _FoodOrdersViewState();
}

class _FoodOrdersViewState extends State<FoodOrdersView> {
  late final DarcapioRepository repository;
  Timer? timer;
  bool busy = false, refreshing = false, loading = true;
  int? company;
  String? error, selectedId;
  List<DarcapioOrder> orders = [];
  List<Map<String, dynamic>> conversations = [];
  String? conversationError;
  FoodStoreIdentity? storeIdentity;
  int? identityCompany;
  DateTime? identityCheckedAt;
  bool identityLoading = false;

  @override
  void initState() {
    super.initState();
    selectedId = widget.initialOrderKey;
    repository = widget.repository ?? DarcapioRepository();
    unawaited(reload());
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy) unawaited(reload());
    });
  }

  @override
  void didUpdateWidget(FoodOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kanban != widget.kanban) selectedId = null;
  }

  String message(Object failure) {
    if (failure is DioException) {
      if ([400, 409, 429, 503].contains(failure.response?.statusCode)) {
        final detail = darcapioField(failure.response?.data, 'mensagem');
        if (detail is String && detail.isNotEmpty) return detail;
      }
      if ([401, 403].contains(failure.response?.statusCode)) {
        return 'Sessão sem acesso. Volte e entre no Food na empresa correta, com permissão de Delivery.';
      }
      return 'Sem confirmação do Service. Atualize antes de tentar novamente; nenhuma etapa foi avançada localmente.';
    }
    return failure.toString().replaceFirst('Bad state: ', '');
  }

  Future<void> reload() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final currentCompany = await repository.useExistingSession();
      if (identityCompany != currentCompany) {
        storeIdentity = null;
        identityCompany = currentCompany;
        identityCheckedAt = null;
      }
      if (!identityLoading &&
          (identityCheckedAt == null ||
              DateTime.now().difference(identityCheckedAt!) >
                  const Duration(minutes: 5))) {
        unawaited(loadStoreIdentity(currentCompany));
      }
      final result = await repository.list();
      try {
        conversations = await repository.conversationSummaries();
        conversationError = null;
      } catch (_) {
        conversationError = 'Atendimento sem conexão. Tente atualizar.';
      }
      if (mounted) {
        setState(() {
          company = currentCompany;
          orders = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          if (e is DioException &&
              [401, 403].contains(e.response?.statusCode)) {
            orders = [];
          }
        });
      }
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadStoreIdentity(int requestedCompany) async {
    identityLoading = true;
    identityCheckedAt = DateTime.now();
    try {
      final identity = await repository.storeIdentity();
      if (mounted &&
          identityCompany == requestedCompany &&
          identity.company == requestedCompany) {
        setState(() => storeIdentity = identity);
      }
    } catch (_) {
      // Branding is optional; keep the generic mark and all orders usable.
    } finally {
      identityLoading = false;
    }
  }

  Future<void> advance(DarcapioOrder order, DarcapioAction action,
      {bool reportInConversation = false}) async {
    if (busy) return;
    // Só o Service decide quais ações existem e se o código é válido.
    setState(() => busy = true);
    if (action.requiresCode) {
      try {
        await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => DeliveryConfirmationDialog(
                pickup: order.pickup,
                orderNumber: order.delivery,
                confirm: (code) =>
                    repository.advance(order, action, code: code),
                describeError: message));
        if (mounted) await reload();
      } finally {
        if (mounted) setState(() => busy = false);
      }
      return;
    }
    DarcapioCourier? courier;
    String? code;
    final dispatch = !order.pickup &&
        (action.requiresCourier || action.action == 'despachar');
    if (dispatch) {
      courier = await showDialog<DarcapioCourier>(
          context: context,
          builder: (_) => CourierDispatchDialog(
              load: repository.couriers, orderNumber: order.delivery));
      code = courier == null ? null : '';
    } else {
      code = await showDialog<String>(
          context: context, builder: (_) => _ConfirmAction(action: action));
    }
    if (!mounted) return;
    if (code == null) {
      setState(() => busy = false);
      return;
    }
    setState(() => error = null);
    try {
      await repository.advance(order, action,
          courierCode: courier?.code,
          reason: action.action == 'cancelar' ? code : null);
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
      if (reportInConversation) rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openConversation(String id) async {
    final destination = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => OrderConversation(
            repository: repository,
            orderId: id,
            getOrder: () => orders.where((o) => o.id == id).firstOrNull,
            onViewOrder: () => Navigator.pop(dialogContext, 'pedido'),
            customer: orders.where((o) => o.id == id).firstOrNull?.customer ??
                'Pedido Darcapio',
            onCancel: orders
                        .where((o) => o.id == id)
                        .firstOrNull
                        ?.actions
                        .any((a) => a.action == 'cancelar') ==
                    true
                ? () async {
                    await reload();
                    final latest = orders.where((o) => o.id == id).firstOrNull;
                    final action = latest?.actions
                        .where((a) => a.action == 'cancelar')
                        .firstOrNull;
                    if (latest != null && action != null) {
                      await advance(latest, action, reportInConversation: true);
                    }
                  }
                : null));
    if (!mounted) return;
    if (destination == 'pedido') {
      setState(() => selectedId = 'darcapio-order-$id');
    }
    await reload();
  }

  Future<void> inbox() async {
    final id = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Atendimento · Darcapio'),
                content: SizedBox(
                    width: 520,
                    height: 400,
                    child: conversations.isEmpty
                        ? Text(conversationError ??
                            'Nenhuma conversa por enquanto. Abra um pedido para falar com o cliente.')
                        : ListView(
                            children: conversations.map((c) {
                            final id = darcapioField(c, 'pedidoId') as String;
                            final order =
                                orders.where((o) => o.id == id).firstOrNull;
                            return ListTile(
                                leading: const Icon(Icons.chat_outlined),
                                title: Text(
                                    'Pedido #${order?.delivery.toString().padLeft(4, '0') ?? id.substring(0, 8).toUpperCase()} · ${order?.customer ?? 'Cliente Darcapio'}'),
                                subtitle: Text(
                                    '${darcapioField(c, 'solicitacoes')} solicitações pendentes · ${darcapioField(c, 'naoLidas')} mensagens novas'),
                                onTap: () => Navigator.pop(context, id));
                          }).toList())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ]));
    if (id != null && mounted) await openConversation(id);
  }

  @override
  void dispose() {
    timer?.cancel();
    repository.dispose();
    super.dispose();
  }

  Future<void> refreshAll() async {
    identityCheckedAt = null;
    await Future.wait([
      reload(),
      if (widget.onRefreshIfood != null && !widget.ifoodLoading)
        widget.onRefreshIfood!(),
    ]);
  }

  Widget connection(String source, bool connecting, bool connected) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            connecting
                ? Icons.sync
                : connected
                    ? Icons.check_circle_outline
                    : Icons.cloud_off_outlined,
            size: 14,
            color: connected ? OrderStyle.teal : OrderStyle.muted),
        const SizedBox(width: 6),
        Text(
            '$source · ${connecting ? 'conectando' : connected ? 'conectado' : 'desconectado'}',
            style: const TextStyle(fontSize: 11, color: OrderStyle.muted)),
      ]);

  @override
  Widget build(BuildContext context) {
    final entries = FoodOrderEntry.combine(widget.ifoodOrders, orders);
    final selected =
        entries.where((order) => order.key == selectedId).firstOrNull;
    final compactHeader = MediaQuery.sizeOf(context).width < 700;
    return FoodOrderBrand(
        source: FoodOrderSource.darcapio,
        store: storeIdentity,
        child: Scaffold(
          backgroundColor: OrderStyle.canvas,
          drawer: widget.drawer,
          appBar: AppBar(
            toolbarHeight: compactHeader ? 64 : 72,
            backgroundColor: OrderStyle.teal,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: compactHeader ? 16 : 24,
            title: Row(children: [
              if (!compactHeader) ...[
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.restaurant_menu, size: 22)),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(compactHeader ? 'Pedidos' : 'Gerenciador de pedidos',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3)),
                    const SizedBox(height: 3),
                    Text(
                        company == null
                            ? 'Kronos Food'
                            : 'Kronos Food · Empresa $company',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: .72))),
                  ])),
            ]),
            actions: [
              IconButton(
                  tooltip: 'Entregadores',
                  icon: const Icon(Icons.delivery_dining_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              CouriersPage(repository: repository)))),
              ...widget.additionalActions,
              IconButton(
                  tooltip: conversationError ?? 'Atendimento e solicitações',
                  onPressed: busy ? null : inbox,
                  icon: Badge(
                      isLabelVisible: conversations.any((c) =>
                          (darcapioField(c, 'naoLidas') as num) > 0 ||
                          (darcapioField(c, 'solicitacoes') as num) > 0),
                      child: const Icon(Icons.forum_outlined))),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: 'Atualizar pedidos',
                  onPressed: busy ? null : refreshAll,
                  icon: const Icon(Icons.refresh, size: 22)),
              SizedBox(width: compactHeader ? 8 : 18),
            ],
          ),
          body: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: OrderStyle.line))),
              child: Wrap(spacing: 24, runSpacing: 8, children: [
                connection(
                    'Darcapio', loading, error == null && company != null),
                if (company != null)
                  DarcapioStoreControl(repository: repository),
                if (widget.ifoodDetailsBuilder != null)
                  connection(
                      'iFood', widget.ifoodLoading, widget.ifoodConnected),
              ]),
            ),
            if (error != null)
              MaterialBanner(
                backgroundColor: const Color(0xFFFFF5E9),
                leading:
                    const Icon(Icons.info_outline, color: Color(0xFFAB722A)),
                content: Text(error!,
                    style:
                        const TextStyle(fontSize: 13, color: OrderStyle.ink)),
                actions: [
                  TextButton(
                      onPressed: busy ? null : reload,
                      child: const Text('Tentar novamente'))
                ],
              ),
            Expanded(child: LayoutBuilder(builder: (context, bounds) {
              final singlePane = bounds.maxWidth < 860 || widget.kanban;
              final list = FoodOrderList(
                attention: {
                  for (final c in conversations)
                    darcapioField(c, 'pedidoId') as String:
                        '${darcapioField(c, 'solicitacoes')} solicitações · ${darcapioField(c, 'naoLidas')} mensagens novas'
                }..removeWhere((key, value) =>
                    value == '0 solicitações · 0 mensagens novas'),
                orders: entries,
                selectedId: selectedId,
                kanban: widget.kanban,
                connected:
                    (error == null && company != null) || widget.ifoodConnected,
                actionsEnabled: !busy && error == null,
                onOrderAction: (entry, action) {
                  final order = entry.darcapioOrder;
                  if (order != null) unawaited(advance(order, action));
                },
                onSelected: (key) {
                  final entry = entries.firstWhere((order) => order.key == key);
                  if (entry.ifoodOrder != null) {
                    widget.onIfoodSelected?.call(entry.ifoodOrder!);
                  }
                  setState(() => selectedId = key);
                },
              );
              final details = selected == null
                  ? const DarcapioOrderEmpty()
                  : selected.darcapioOrder != null
                      ? DarcapioOrderDetails(
                          key: ValueKey('details-${selected.key}'),
                          order: selected.darcapioOrder!,
                          repository: repository,
                          busy: busy,
                          blocked: error != null,
                          onAction: (action) =>
                              advance(selected.darcapioOrder!, action),
                          onChat: () =>
                              openConversation(selected.darcapioOrder!.id),
                          onBack: singlePane
                              ? () => setState(() => selectedId = null)
                              : null,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              if (singlePane || !widget.ifoodConnected)
                                Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 1256),
                                        child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                bounds.maxWidth < 650 ? 16 : 28,
                                                12,
                                                bounds.maxWidth < 650 ? 16 : 28,
                                                0),
                                            child: Row(children: [
                                              if (singlePane)
                                                TextButton.icon(
                                                    onPressed: () => setState(
                                                        () =>
                                                            selectedId = null),
                                                    icon: const Icon(
                                                        Icons.arrow_back,
                                                        size: 18),
                                                    label: const Text(
                                                        'Voltar à lista')),
                                              if (!widget.ifoodConnected) ...[
                                                const SizedBox(width: 12),
                                                const Expanded(
                                                    child: Text(
                                                        'Reconecte ao iFood para atualizar este pedido.',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: OrderStyle
                                                                .muted))),
                                              ],
                                            ])))),
                              Expanded(
                                  child: AbsorbPointer(
                                      absorbing: !widget.ifoodConnected,
                                      child: widget.ifoodDetailsBuilder
                                              ?.call(selected.ifoodOrder!) ??
                                          const DarcapioOrderEmpty())),
                            ]);
              if (singlePane) return selected == null ? list : details;
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: bounds.maxWidth < 1200 ? 340 : 370, child: list),
                    const VerticalDivider(
                        width: 1, thickness: 1, color: OrderStyle.line),
                    Expanded(child: details),
                  ]);
            })),
          ]),
        ));
  }
}

class _ConfirmAction extends StatefulWidget {
  final DarcapioAction action;
  const _ConfirmAction({required this.action});
  @override
  State<_ConfirmAction> createState() => _ConfirmActionState();
}

class _ConfirmActionState extends State<_ConfirmAction> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.action.label),
          content: SizedBox(
              width: 420,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.action.action == 'cancelar'
                        ? 'Cancelar este pedido e a venda vinculada no ERP? Informe o motivo para o cliente. Esta ação encerra o pedido.'
                        : 'Confirmar esta etapa para o cliente acompanhar no Darcapio?'),
                    if (widget.action.action == 'cancelar') ...[
                      const SizedBox(height: 16),
                      TextField(
                          controller: code,
                          autofocus: true,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                              labelText: 'Motivo do cancelamento',
                              border: OutlineInputBorder())),
                    ],
                  ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar')),
            FilledButton(
                onPressed: (widget.action.action == 'cancelar' &&
                        code.text.trim().length < 3)
                    ? null
                    : () => Navigator.pop(context, code.text),
                child: const Text('Confirmar'))
          ]);
}
