import 'package:flutter/material.dart';
import '../components/darcapio/courier_access_card.dart';
import '../components/darcapio/courier_invite_card.dart';
import '../components/darcapio/order_style.dart';
import '../controllers/couriers_controller.dart';
import '../models/courier_management.dart';
import '../repositories/darcapio_repository.dart';

class CouriersPage extends StatefulWidget {
  final DarcapioRepository? repository;
  const CouriersPage({super.key, this.repository});
  @override
  State<CouriersPage> createState() => _CouriersPageState();
}

class _CouriersPageState extends State<CouriersPage> {
  late final CouriersController controller;
  @override
  void initState() {
    super.initState();
    controller = CouriersController(widget.repository ?? DarcapioRepository())
      ..start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> act(CourierAccess courier, {bool revoke = false}) async {
    if (revoke || courier.hasAccess) {
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(revoke
                      ? 'Encerrar acesso de ${courier.name}?'
                      : 'Gerar outro convite para ${courier.name}?'),
                  content: Text(revoke
                      ? 'O celular será desconectado e deixará de enviar localização. Os pedidos continuam atribuídos ao entregador.'
                      : 'O convite e o acesso anteriores serão encerrados. O entregador precisará conectar o celular com o novo convite.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Voltar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                            revoke ? 'Encerrar acesso' : 'Gerar novo convite'))
                  ]));
      if (approved != true || !mounted) return;
    }
    if (revoke) {
      await controller.revoke(courier);
    } else {
      await controller.generate(courier);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: OrderStyle.teal)),
      child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Scaffold(
              backgroundColor: OrderStyle.canvas,
              appBar: AppBar(
                  backgroundColor: OrderStyle.teal,
                  foregroundColor: Colors.white,
                  title: const Text('Entregadores'),
                  actions: [
                    IconButton(
                        tooltip: 'Atualizar entregadores',
                        onPressed: controller.busy ? null : controller.reload,
                        icon: const Icon(Icons.refresh)),
                    const SizedBox(width: 16)
                  ]),
              body: controller.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(
                          MediaQuery.sizeOf(context).width < 700 ? 16 : 32),
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        controller.data?.storeName ??
                                            'Equipe de entrega',
                                        style: const TextStyle(
                                            color: OrderStyle.muted)),
                                    const SizedBox(height: 10),
                                    const Text('Sua equipe na rua',
                                        style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: OrderStyle.ink)),
                                    const SizedBox(height: 10),
                                    const Text(
                                        'Conecte o celular de cada entregador e gerencie os acessos por aqui.',
                                        style: TextStyle(
                                            color: OrderStyle.muted,
                                            fontSize: 16)),
                                    const SizedBox(height: 24),
                                    Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                            color: OrderStyle.softTeal,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Text(
                                            'Os entregadores vêm do cadastro ativo do ERP. Cada convite conecta um celular. Gerar outro encerra o acesso anterior.')),
                                    const SizedBox(height: 24),
                                    if (controller.error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 20),
                                          child: MaterialBanner(
                                              content: Text(controller.error!),
                                              backgroundColor:
                                                  const Color(0xFFFFF0F0),
                                              actions: [
                                                TextButton(
                                                    onPressed: controller.busy
                                                        ? null
                                                        : controller.reload,
                                                    child: const Text(
                                                        'Tentar novamente'))
                                              ])),
                                    if (controller.notice != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 20),
                                          child: Text(controller.notice!,
                                              style: const TextStyle(
                                                  color: OrderStyle.teal))),
                                    if (controller.busy)
                                      const Padding(
                                          padding: EdgeInsets.only(bottom: 20),
                                          child: LinearProgressIndicator()),
                                    if (controller.invite != null)
                                      CourierInviteCard(
                                          invite: controller.invite!,
                                          name:
                                              controller.invitedCourier!.name),
                                    if (controller.data != null &&
                                        controller.data!.storeUrl == null)
                                      const Padding(
                                          padding: EdgeInsets.only(bottom: 20),
                                          child: Text(
                                              'A loja precisa de um endereço HTTPS público configurado no Darcapio para conectar os celulares.')),
                                    for (final courier
                                        in controller.data?.couriers ??
                                            <CourierAccess>[])
                                      CourierAccessCard(
                                          courier: courier,
                                          onInvite: controller.busy ||
                                                  controller.data?.storeUrl ==
                                                      null
                                              ? null
                                              : () => act(courier),
                                          onRevoke: controller.busy
                                              ? null
                                              : () =>
                                                  act(courier, revoke: true)),
                                    if (controller.data?.couriers.isEmpty ==
                                        true)
                                      const OrderPanel(
                                          title: 'Nenhum entregador disponível',
                                          icon: Icons.delivery_dining_outlined,
                                          child: Text(
                                              'Cadastre um funcionário ativo com cargo de entregador no ERP e sincronize a integração da loja.')),
                                  ])))))));
}
