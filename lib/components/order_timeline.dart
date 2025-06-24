import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderTimeline extends StatelessWidget {
  final PedidoModel order;

  const OrderTimeline({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    print("⏰ OrderTimeline build - Status: ${order.status}");
    
    final timelineStates = _getTimelineStates();
    print("⏰ Timeline states count: ${timelineStates.length}");

    // Se não houver estados para mostrar, exibe uma mensagem
    if (timelineStates.isEmpty) {
      print("⚠️ Timeline sem estados para mostrar");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Status do Pedido',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text("Não há informações de timeline disponíveis"),
            ),
          ),
        ],
      );
    }

    // Se há apenas um estado, não precisamos de conectores
    final int itemCount = timelineStates.length > 1 ? timelineStates.length * 2 - 1 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Status do Pedido',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Timeline horizontal com círculos e linhas conectoras
              SizedBox(
                height: 100,
                child: Row(
                  children: List.generate(itemCount, (index) {
                    // Índices pares são para nós (círculos), ímpares para conectores (linhas)
                    if (index % 2 == 0) {
                      final stateIndex = index ~/ 2;
                      final state = timelineStates[stateIndex];
                      final isActive = state['active'] as bool;
                      final time = state['time'] as DateTime?;

                      return Expanded(
                        child: Column(
                          children: [
                            // Círculo com ícone
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (state['color'] as Color)
                                    : Colors.grey[200],
                                shape: BoxShape.circle,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: (state['color'] as Color)
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                state['icon'] as IconData,
                                size: 20,
                                color:
                                    isActive ? Colors.white : Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Título do estado
                            Text(
                              state['title'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? (state['color'] as Color)
                                    : Colors.grey[500],
                              ),
                            ),
                            // Hora (se disponível)
                            if (time != null && isActive)
                              Text(
                                _formatTime(time),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive
                                      ? (state['color'] as Color)
                                      : Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      );
                    } else {
                      // Linhas conectoras entre os círculos
                      final lineIndex = index ~/ 2;
                      final states = timelineStates;
                      
                      // Verificação dupla de segurança para índices
                      if (lineIndex < 0 || lineIndex >= states.length || lineIndex + 1 >= states.length) {
                        print("❌ Índice inválido para linha conectora: $lineIndex (total de estados: ${states.length})");
                        return const Expanded(
                          child: SizedBox(), // Retorna um espaço vazio se os índices estiverem fora do intervalo
                        );
                      }
                      
                      // Obter os valores com verificação de tipo
                      final beforeActive = states[lineIndex]['active'] as bool? ?? false;
                      final afterActive = states[lineIndex + 1]['active'] as bool? ?? false;
                      final color = states[lineIndex]['color'] as Color? ?? Colors.grey[300]!;

                      // Determina a cor da linha baseado nos status antes e depois
                      Color lineColor;
                      if (beforeActive && afterActive) {
                        // Ambos os estados estão ativos
                        lineColor = color;
                      } else if (beforeActive) {
                        // Apenas o estado anterior está ativo
                        lineColor = Colors.grey[300]!;
                      } else {
                        // Nenhum estado ativo ou apenas o próximo está ativo
                        lineColor = Colors.grey[300]!;
                      }

                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 38),
                          decoration: BoxDecoration(
                            color: lineColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }
                  }),
                ),
              ),

              // Indicador de progresso atual
              const SizedBox(height: 12),
              AnimatedProgressIndicator(value: _calculateProgress()),
            ],
          ),
        ),
      ],
    );
  }

  // Calcula o progresso baseado no status atual
  double _calculateProgress() {
    switch (order.status) {
      case Consts.statusPlaced:
        return 0.25;
      case Consts.statusConfirmed:
        return 0.50;
      case Consts.statusDispatched:
        return 0.75;
      case Consts.statusConcluded:
        return 1.0;
      case Consts.statusCancelled:
        return 0.0;
      default:
        return 0.0;
    }
  }

  // Método para garantir que haja eventos que correspondam ao status atual do pedido
  List<Map<String, dynamic>> _getTimelineStates() {
    // Debug para verificar os eventos e status
    print("Timeline debug - Status: ${order.status}, Eventos: ${order.events.length}");
    
    // Se não temos eventos, vamos criar um evento para o status atual
    if (order.events.isEmpty) {
      print("Criando evento sintético para o status atual: ${order.status}");
      
      // Adiciona um evento para o status "Recebido" se não existir
      // if (order.status != Consts.statusCancelled) {
      //   _ensureEventExists(Consts.statusPlaced);
      // }
      
      // Adiciona eventos com base no status atual
      _ensureEventExists(order.status);
    }
    
    // Lista para armazenar os estados da timeline
    final List<Map<String, dynamic>> timelineStates = [];
    
    // 1. Primeiro, vamos sempre garantir um estado mínimo baseado no status atual
    
    // Pedido recebido (sempre presente exceto se cancelado antes de confirmar)
    if (order.status != Consts.statusCancelled || order.events.any((e) => e.code != Consts.statusCancelled)) {
      timelineStates.add({
        'title': 'Pedido Recebido',
        'time': order.createdAt,
        'icon': Icons.receipt,
        'color': Colors.orange,
        'status': Consts.statusPlaced,
        'active': true, // Sempre ativo pois todo pedido foi recebido
      });
    }
    
    // 2. Se temos eventos, adicionamos estados com base neles
    if (order.events.isNotEmpty) {
      print("Timeline debug - Usando ${order.events.length} eventos para a timeline");
      
      // Ordena os eventos por data de criação
      final sortedEvents = List.from(order.events)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Adiciona estados baseados nos eventos (exceto o "Recebido" que já foi adicionado)
      for (final e in sortedEvents) {
        if (e.code == Consts.statusPlaced) continue; // Pula, já adicionamos o "Recebido"
        
        if (e.code == Consts.statusConfirmed) {
          timelineStates.add({
            'title': 'Pedido Confirmado',
            'time': e.createdAt,
            'icon': Icons.check_circle,
            'color': Colors.blue,
            'status': Consts.statusConfirmed,
            'active': true,
          });
        } else if (e.code == Consts.statusDispatched) {
          timelineStates.add({
            'title': 'Pedido Despachado',
            'time': e.createdAt,
            'icon': Icons.delivery_dining,
            'color': Colors.purple,
            'status': Consts.statusDispatched,
            'active': true,
          });
        } else if (e.code == Consts.statusConcluded) {
          timelineStates.add({
            'title': 'Pedido Concluído',
            'time': e.createdAt,
            'icon': Icons.check_circle_outline,
            'color': Colors.green,
            'status': Consts.statusConcluded,
            'active': true,
          });
        } else if (e.code == Consts.statusCancelled) {
          timelineStates.add({
            'title': 'Pedido Cancelado',
            'time': e.createdAt,
            'icon': Icons.cancel_outlined,
            'color': Colors.redAccent,
            'status': Consts.statusCancelled,
            'active': true,
          });
        } else {
          // Caso não seja um status conhecido, adiciona um padrão
          timelineStates.add({
            'title': e.code,
            'time': e.createdAt,
            'icon': Icons.help_outline,
            'color': Colors.grey[400]!,
            'status': e.code,
            'active': true,
          });
        }
      }
    } else {
      // Se não temos eventos mesmo após tentar criar, usamos o status atual
      // Isso é um fallback adicional
      print("Timeline debug - Sem eventos, usando o status atual: ${order.status}");
      
      // Se o pedido está confirmado ou em estado posterior
      if (order.status == Consts.statusConfirmed || 
          order.status == Consts.statusDispatched || 
          order.status == Consts.statusConcluded) {
        timelineStates.add({
          'title': 'Pedido Confirmado',
          'time': DateTime.now(),
          'icon': Icons.check_circle,
          'color': Colors.blue,
          'status': Consts.statusConfirmed,
          'active': true,
        });
      }
      
      // Se o pedido está despachado ou concluído
      if (order.status == Consts.statusDispatched || 
          order.status == Consts.statusConcluded) {
        timelineStates.add({
          'title': 'Pedido Despachado',
          'time': DateTime.now(),
          'icon': Icons.delivery_dining,
          'color': Colors.purple,
          'status': Consts.statusDispatched,
          'active': true,
        });
      }
      
      // Se o pedido está concluído
      if (order.status == Consts.statusConcluded) {
        timelineStates.add({
          'title': 'Pedido Concluído',
          'time': DateTime.now(),
          'icon': Icons.check_circle_outline,
          'color': Colors.green,
          'status': Consts.statusConcluded,
          'active': true,
        });
      }
      
      // Se o pedido está cancelado
      if (order.status == Consts.statusCancelled) {
        timelineStates.add({
          'title': 'Pedido Cancelado',
          'time': DateTime.now(),
          'icon': Icons.cancel_outlined,
          'color': Colors.redAccent,
          'status': Consts.statusCancelled,
          'active': true,
        });
      }
    }
    
    print("Timeline debug - Total de estados criados: ${timelineStates.length}");
    
    // Garantir que temos pelo menos um estado
    if (timelineStates.isEmpty) {
      print("AVISO: Nenhum estado foi criado para a timeline. Status do pedido: ${order.status}");
      
      // Adiciona um estado genérico para evitar uma timeline vazia
      timelineStates.add({
        'title': 'Status atual: ${order.status}',
        'time': order.createdAt,
        'icon': Icons.receipt,
        'color': Colors.grey,
        'status': order.status,
        'active': true,
      });
    }
    
    return timelineStates;
  }
  
  // Adiciona um evento ao pedido se não existir um com o código especificado
  void _ensureEventExists(String statusCode) {
    // Verificar se já existe um evento com este código
    final hasEvent = order.events.any((e) => e.code == statusCode);
    
    if (!hasEvent) {
      // Criar um novo evento com o código de status
      final newEvent = EventModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        code: statusCode,
        orderId: order.id,
        createdAt: DateTime.now(),
        salesChannel: order.salesChannel,
        merchantId: order.merchant.id,
      );
      
      // Adicionar o evento à lista
      order.events.add(newEvent);
      print("✅ Evento adicionado localmente para o status: $statusCode");
    }
  }

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal(); // Converte para o horário local
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}

// Componente de barra de progresso animada
class AnimatedProgressIndicator extends StatelessWidget {
  final double value;

  const AnimatedProgressIndicator({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 8,
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Consts.primaryColor.withValues(alpha: .1),
                      Consts.primaryColor
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
