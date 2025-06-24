## O aplicativo deve ser capaz de:
- [x] Receber eventos de pedidos via polling ou via webhook.
No caso do polling:
- [x] Fazer requests no endpoint de /polling regularmente a cada 30 segundos para não perder nenhum pedido. Isso garante que o merchant fique aberto na plataforma; Utilize o header x-polling-merchants sempre que precisar filtrar eventos de um ou mais merchants. Também é possível filtrar os eventos que deseja receber por tipo e por grupo;
- [x] !!! Enviar /acknowledgment para todos os eventos recebidos (com status code 200) imediatamente após a request de polling;
- No caso do webhook: responder com sucesso às requests do webhook, verificado por nossa auditoria interna;
- [x] Receber, confirmar e despachar um pedido delivery para agora (orderType = DELIVERY / orderTiming = IMMEDIATE);
- [x] Receber, confirmar e despachar um pedido delivery agendado (orderType = DELIVERY / orderTiming = SCHEDULED). É necessário exibir a data e hora do agendamento;
- [] Receber e cancelar um pedido delivery para agora (orderType =  DELIVERY / orderTiming = IMMEDIATE). Antes de solicitar um cancelamento é obrigatório a consulta dos códigos/motivos disponíveis para o momento do pedido através do endpoint /cancellationReasons, esta lista de códigos/motivos deverá ser disponibilizada no sistema de PDV, para o usuário do PDV escolher qual motivo usar;
- [x] Receber, confirmar e avisar que está pronto um pedido Pra Retirar (orderType = TAKEOUT);
- [x] Receber pedidos com pagamento em cartão e exibir detalhes do tipo de pagamento, como bandeira;
- [x] Receber pedidos com pagamento em dinheiro e exibir o valor do troco na tela e/ou comanda impressa;
- [x] Receber pedidos com todos os cupons de desconto e exibir o valor e o responsável pelo subsídio (iFood / Loja);
- [x] Exibir observações dos itens na tela e/ou comanda impressa (Ex: Retirar cebola);
- [x] Atualizar o status de um pedido cancelado pelo cliente ou pelo iFood;
- [x] Atualizar o status de um pedido que pode ter sido confirmado/cancelado por outro aplicativo como por exemplo o Gestor de Pedidos;
- [] Receber um mesmo evento mais de uma vez no polling e descartá-lo caso esse evento tenha sido entregue mais de uma vez;
- [x] Informar o CPF/CNPJ na tela caso seja obrigatório pela loja ou já preencher no documento fiscal automaticamente;
- [] Receber eventos da Plataforma de Negociação de Pedidos e ser capaz de processá-los através dos endpoints disponíveis;
- [x] Exibir na tela e/ou impresso na comanda o código de coleta do pedido;
### Requisitos não funcionais:
- [x] Renovar o token somente quando estiver prestes a expirar ou imediatamente após a expiração.
- [x] O aplicativo deve respeitar as políticas de rate limit de cada endpoint.
### Desejável:
- A comanda impressa seguir o modelo sugerido na documentação é um requisito desejável.
- Informar na tela e/ou comanda impressa a informação de indicar qualquer observação sobre a entrega do pedido (que vem no campo delivery.observations)