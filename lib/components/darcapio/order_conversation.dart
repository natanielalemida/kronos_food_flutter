import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../repositories/darcapio_repository.dart';
import 'order_style.dart';

class OrderConversation extends StatefulWidget {
  final DarcapioRepository repository;
  final String orderId;
  final String customer;
  final DarcapioOrder? Function()? getOrder;
  final VoidCallback? onViewOrder;
  final Future<void> Function()? onCancel;
  const OrderConversation(
      {super.key,
      required this.repository,
      required this.orderId,
      required this.customer,
      this.getOrder,
      this.onViewOrder,
      this.onCancel});
  @override
  State<OrderConversation> createState() => _OrderConversationState();
}

class _OrderConversationState extends State<OrderConversation> {
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  bool busy = false, loading = true, refreshing = false, more = false;
  String? error, attempt, fingerprint, photoType;
  Uint8List? photo;
  int read = 0;
  List<Map<String, dynamic>> messages = [], pending = [];
  final Map<String, Future<Uint8List>> photos = {};
  dynamic f(dynamic value, String key) => darcapioField(value, key);
  @override
  void initState() {
    super.initState();
    unawaited(reload());
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy) unawaited(reload());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  String failure(Object e) => e is DioException
      ? f(e.response?.data, 'mensagem')?.toString() ??
          'Não foi possível acessar a conversa. Confira a conexão e sua permissão de Delivery.'
      : e.toString().replaceFirst('Bad state: ', '');
  Future<void> reload({bool older = false}) async {
    if (refreshing) return;
    refreshing = true;
    try {
      final data = await widget.repository.conversation(widget.orderId,
          before: older && messages.isNotEmpty
              ? (f(messages.first, 'sequencia') as num).toInt()
              : null);
      final page = (f(data, 'mensagens') as List)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      final nearBottom = !scroll.hasClients || scroll.position.extentAfter < 80;
      final previousLast = messages.isEmpty ? 0 : f(messages.last, 'sequencia');
      final merged = {
        for (final m in messages) f(m, 'id'): m,
        for (final m in page) f(m, 'id'): m
      }.values.toList()
        ..sort((a, b) =>
            (f(a, 'sequencia') as int).compareTo(f(b, 'sequencia') as int));
      setState(() {
        if (older || messages.isEmpty) more = f(data, 'temAnteriores') == true;
        messages = merged;
        pending = (f(data, 'pendentes') as List)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        loading = false;
        error = null;
      });
      if (!older &&
          nearBottom &&
          messages.isNotEmpty &&
          previousLast != f(messages.last, 'sequencia')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients) {
            scroll.jumpTo(scroll.position.maxScrollExtent);
          }
        });
      }
      if (messages.isNotEmpty) {
        final last = (f(messages.last, 'sequencia') as num).toInt();
        if (last > read) {
          await widget.repository
              .conversationPost(widget.orderId, 'lida', {'ateSequencia': last});
          read = last;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = failure(e);
          loading = false;
        });
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> choosePhoto() async {
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Fotos JPG e PNG',
            extensions: ['jpg', 'jpeg', 'png'],
            uniformTypeIdentifiers: ['public.jpeg', 'public.png'])
      ]);
      if (file == null || !mounted) return;
      if (await file.length() > 2097152) {
        throw StateError('Escolha uma foto de até 2 MB.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          photo = bytes;
          photoType = file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    }
  }

  Future<void> send() async {
    if (busy || text.text.trim().isEmpty && photo == null) return;
    final body = {
      'texto': text.text.trim(),
      'tipo': 'mensagem',
      if (photo != null) 'fotoBase64': base64Encode(photo!),
      if (photo != null) 'fotoTipo': photoType
    };
    final next = jsonEncode(body);
    if (next != fingerprint) {
      fingerprint = next;
      attempt = const Uuid().v4();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.conversationPost(
          widget.orderId, 'mensagens', {...body, 'id': attempt});
      if (!mounted) return;
      setState(() {
        text.clear();
        photo = null;
        fingerprint = null;
        attempt = null;
      });
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resolve(Map<String, dynamic> request, String decision) async {
    final reply = await showDialog<String>(
        context: context,
        builder: (_) => _ResponseDialog(accepted: decision == 'atendida'));
    if (reply == null || !mounted) return;
    final body = {'decisao': decision, 'resposta': reply};
    final next = '${f(request, 'id')}:${jsonEncode(body)}';
    if (next != fingerprint) {
      fingerprint = next;
      attempt = const Uuid().v4();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.conversationPost(
          widget.orderId,
          'solicitacoes/${f(request, 'id')}/resposta',
          {...body, 'id': attempt});
      fingerprint = null;
      attempt = null;
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      child: SizedBox(
          width: 650,
          height: MediaQuery.sizeOf(context).height * .88,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const Icon(Icons.chat_outlined, color: OrderStyle.teal),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            'Pedido #${widget.getOrder?.call()?.delivery.toString().padLeft(4, '0') ?? widget.orderId.substring(0, 8).toUpperCase()}',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('Conversa com ${widget.customer}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: OrderStyle.muted))
                      ])),
                  IconButton(
                      tooltip: 'Fechar conversa',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ])),
            orderContext(),
            if (error != null)
              Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFFFEBEE),
                  child: Row(children: [
                    Expanded(child: Text(error!)),
                    TextButton(
                        onPressed: () => reload(),
                        child: const Text('Atualizar'))
                  ])),
            if (pending.isNotEmpty)
              ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 210),
                  child: SingleChildScrollView(
                      child: Column(
                          children: pending
                              .map((p) => Container(
                                  width: double.infinity,
                                  margin:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4E5),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            f(p, 'tipo') == 'cancelamento'
                                                ? 'Cliente solicitou cancelamento'
                                                : 'Cliente solicitou alteração',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 6),
                                        Text(f(p, 'texto') as String),
                                        Wrap(spacing: 10, children: [
                                          if (f(p, 'tipo') == 'cancelamento')
                                            TextButton.icon(
                                                onPressed: busy ||
                                                        widget.onCancel == null
                                                    ? null
                                                    : () async {
                                                        setState(
                                                            () => busy = true);
                                                        try {
                                                          await widget
                                                              .onCancel!();
                                                          await reload();
                                                        } catch (e) {
                                                          if (mounted)
                                                            setState(() =>
                                                                error =
                                                                    failure(e));
                                                        } finally {
                                                          if (mounted)
                                                            setState(() =>
                                                                busy = false);
                                                        }
                                                      },
                                                icon: const Icon(
                                                    Icons.cancel_outlined),
                                                label: const Text(
                                                    'Aceitar cancelamento'))
                                          else
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                        resolve(p, 'atendida'),
                                                child: const Text(
                                                    'Marcar alteração atendida')),
                                          TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () =>
                                                      resolve(p, 'recusada'),
                                              child: const Text(
                                                  'Recusar solicitação'))
                                        ]),
                                        if (f(p, 'tipo') == 'alteracao')
                                          const Text(
                                              'Combine com o cliente e faça os ajustes necessários antes de marcar atendida.',
                                              style: TextStyle(fontSize: 11))
                                      ])))
                              .toList()))),
            Expanded(
                child: ColoredBox(
                    color: const Color(0xFFF5F8F7),
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty
                            ? const Center(
                                child: Text(
                                    'Envie uma mensagem para iniciar a conversa.'))
                            : ListView(
                                controller: scroll,
                                padding: const EdgeInsets.all(16),
                                children: [
                                    if (more)
                                      TextButton(
                                          onPressed: () => reload(older: true),
                                          child: const Text(
                                              'Carregar mensagens anteriores')),
                                    ...messages.map(message),
                                  ]))),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (photo != null)
                        Row(children: [
                          Image.memory(photo!,
                              width: 70,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Text('Foto inválida')),
                          IconButton(
                              tooltip: 'Remover foto',
                              onPressed: busy
                                  ? null
                                  : () => setState(() => photo = null),
                              icon: const Icon(Icons.close))
                        ]),
                      TextField(
                          controller: text,
                          enabled: !busy,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                              labelText: 'Mensagem ao cliente',
                              hintText: 'Escreva sua resposta…',
                              border: OutlineInputBorder())),
                      Row(children: [
                        TextButton.icon(
                            onPressed: busy ? null : choosePhoto,
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Anexar foto')),
                        const Spacer(),
                        FilledButton.icon(
                            onPressed: busy ||
                                    text.text.trim().isEmpty && photo == null
                                ? null
                                : send,
                            icon: const Icon(Icons.send, size: 17),
                            label: Text(busy ? 'Enviando…' : 'Enviar'))
                      ]),
                      const Text(
                          'JPG ou PNG · até 2 MB · Atualização automática',
                          style:
                              TextStyle(fontSize: 11, color: OrderStyle.muted))
                    ])),
          ])));
  Widget orderContext() {
    final order = widget.getOrder?.call();
    if (order == null) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: const BoxDecoration(
            color: Color(0xFFEAF5F2),
            border: Border(bottom: BorderSide(color: OrderStyle.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Wrap(spacing: 16, runSpacing: 6, children: [
              Text(order.label,
                  style: const TextStyle(
                      color: OrderStyle.teal, fontWeight: FontWeight.w700)),
              Text(order.pickup ? 'Retirada na loja' : 'Entrega no endereço'),
              Text(
                  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                      .format(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
            if (widget.onViewOrder != null)
              TextButton.icon(
                  onPressed: busy ? null : widget.onViewOrder,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Ver pedido')),
          ]),
          const SizedBox(height: 6),
          Text(
              order.items
                  .map((item) =>
                      '${f(item, 'quantidade')}× ${f(item, 'descricao')}')
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: OrderStyle.muted)),
        ]));
  }

  Widget message(Map<String, dynamic> m) {
    final own = f(m, 'autor') == 'loja';
    final id = f(m, 'id') as String;
    final kind = f(m, 'tipo');
    return Align(
        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: own ? OrderStyle.softTeal : Colors.white,
                border: Border.all(color: OrderStyle.line),
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(own ? 'Loja' : 'Cliente',
                  style: const TextStyle(
                      fontSize: 11,
                      color: OrderStyle.teal,
                      fontWeight: FontWeight.w700)),
              if (kind != 'mensagem')
                Text(
                    '${kind == 'cancelamento' ? 'Cancelamento' : 'Alteração'} · ${f(m, 'situacao')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((f(m, 'texto') as String).isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SelectableText(f(m, 'texto') as String)),
              if (f(m, 'temFoto') == true)
                FutureBuilder<Uint8List>(
                    future: photos.putIfAbsent(
                        id,
                        () => widget.repository
                            .conversationPhoto(widget.orderId, id)),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return TextButton(
                            onPressed: () => setState(() => photos.remove(id)),
                            child:
                                const Text('Tentar carregar foto novamente'));
                      }
                      if (!snap.hasData) {
                        return const SizedBox(
                            width: 150,
                            height: 80,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      return InkWell(
                          onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => Dialog(
                                      child: Stack(children: [
                                    InteractiveViewer(
                                        child: Image.memory(snap.data!,
                                            fit: BoxFit.contain)),
                                    Positioned(
                                        right: 0,
                                        top: 0,
                                        child: IconButton(
                                            tooltip: 'Fechar foto',
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            icon: const Icon(Icons.close)))
                                  ]))),
                          child: Image.memory(snap.data!,
                              height: 170,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                  'Não foi possível exibir a foto.')));
                    }),
              if (f(m, 'resposta') != null)
                Text('Resposta: ${f(m, 'resposta')}',
                    style: const TextStyle(fontSize: 12)),
              Text(
                  '${DateFormat('dd/MM · HH:mm').format(DateTime.parse(f(m, 'criadoEm')).toLocal())}${own && f(m, 'lidaEm') != null ? ' · Lida' : ''}',
                  style: const TextStyle(fontSize: 10, color: OrderStyle.muted))
            ])));
  }
}

class _ResponseDialog extends StatefulWidget {
  final bool accepted;
  const _ResponseDialog({required this.accepted});
  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final reply = TextEditingController();
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.accepted
              ? 'Confirmar alteração atendida'
              : 'Recusar solicitação'),
          content: SizedBox(
              width: 400,
              child: TextField(
                  controller: reply,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1800,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Explique ao cliente',
                      helperText: 'A resposta ficará registrada na conversa.',
                      border: OutlineInputBorder()))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar')),
            FilledButton(
                onPressed: reply.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(context, reply.text.trim()),
                child: const Text('Confirmar resposta'))
          ]);
}
