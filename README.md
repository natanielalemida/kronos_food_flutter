## Gestão de entregadores

O menu **Entregadores** e o atalho de moto no cabeçalho dos pedidos abrem a gestão
de acesso ao Kronos Entregador. Administradores podem gerar/copiar convites e
encerrar o acesso de um celular, além de consultar entregas em andamento e o
estado do compartilhamento de localização. Cada convite vale 15 minutos e é de
uso único; gerar outro invalida o anterior. O cadastro dos nomes continua no ERP.

O fluxo é Food → Kronos Service → Darcapio, com a sessão Food existente e validação
de administrador nos servidores. Os três componentes precisam estar atualizados;
a loja precisa de domínio público HTTPS ativo e verificado para emitir convites.
Verificação: `flutter test test/courier_management_test.dart`.
Relatório: `E:/ARC-SOLUTION/docs/kronos-food-entregadores-20260915.md`.

## Pedidos integrados no Kronos Food

Cards, detalhes, histórico e cupons mostram **X pedidos na loja** ao lado dos
dados do cliente. No Darcapio, o Service conta todo o histórico já recebido da
conta naquela empresa, incluindo o pedido atual e os concluídos, sem limitar ao
movimento de caixa. Cancelados e recusados (persistidos como `cancelado`) ficam
fora. A contagem é recalculada a cada consulta; pedidos antigos mostram o total
atual do cliente. O CSV do histórico também inclui essa coluna.

No iFood, o app preserva `customer.ordersCountOnMerchant`, sem somar um pedido.
A [documentação do iFood](https://developer.ifood.com.br/en-US/docs/food/guides/modules/order/details)
define a janela como os últimos cinco anos. O cupom manual e o automático
imprimem a contagem. Dado ausente é omitido, e zero informado continua sendo zero.

Atualizar o KronosServices da árvore `ArcSolution_Services_Desenvolvimento` com
o campo opcional `PedidosClienteNaLoja` no contrato Food e a ArcSolutionLib com
`OrdersCountOnMerchant` anulável, além do Flutter Windows. Não há migration;
clientes e pedidos existentes já permitem calcular o histórico Darcapio.
Servidores antigos continuam funcionando e apenas não exibem a contagem Darcapio.
Verificação: `flutter test test/customer_order_count_test.dart` e
`ContagemPedidosClienteTests` no projeto `KronosServices.Darcapio.Tests`.

O botão **Entrar** autentica no Kronos Food e já libera o Darcapio com a mesma
sessão. Não há botão nem formulário de login separado para o Darcapio. Pedidos
iFood e Darcapio aparecem juntos, agrupados por etapa, tanto na lista quanto no
kanban. Cada cartão e seus detalhes têm uma etiqueta de origem. Busca e filtros
consideram os dois canais; a identidade inclui a origem para evitar colisões.
As conexões atualizam independentemente, com seu estado no cabeçalho. Uma falha
em um canal não bloqueia o outro. Detalhes e ações usam o contrato de cada origem;
pedidos Darcapio nunca são enviados às ações ou automações do iFood.

A lista Darcapio acompanha o **movimento de caixa aberto usado pelo recebimento
no ERP**. O vínculo é o código de movimento da pré-venda, sem corte por data:
um caixa que atravessa a meia-noite mantém todos os seus pedidos. Ao fechar o
caixa, a lista fica vazia; ao abrir outro, passa a exibir o novo movimento na
próxima atualização automática. **Todos** inclui concluídos e cancelados do
movimento atual. Sem caixa aberto, o histórico continua disponível.

**Histórico Darcapio** permite escolher entre os 100 movimentos mais recentes
com pedidos ou buscar um movimento anterior pelo número. A consulta é paginada,
inclui todos os status, permite imprimir o cupom e exportar todos os pedidos do
movimento em CSV. O histórico não oferece ações para avançar ou cancelar pedidos.
O filtro vale somente para Darcapio; a consulta do iFood segue independente.
Food e Service devem ser atualizados juntos; esta mudança usa o vínculo de caixa
já existente e não exige migração do banco.
Verificação: `flutter test test/food_cash_movement_test.dart` e os testes
`MovimentoCaixaFoodTests` do Service.

O fluxo Darcapio usa **Aguardando aceite → Em preparo → Pronto → Em rota de
entrega → Concluído**. Aceitar já inicia o preparo, sem uma ação intermediária.
Retirada pula a rota; cancelamentos continuam identificados. Pedidos antigos
com status `aceito` aparecem em preparo e podem avançar diretamente para pronto.
As ações continuam vindo do servidor, que deve ser atualizado junto com o Food.

Os cartões Darcapio mostram **Aceitar** e **Recusar** durante o aceite. Depois,
mostram a próxima ação permitida: **Marcar como pronto**, **Marcar em rota de
entrega** e **Marcar como concluído**. Na retirada, **Pronto** oferece **Confirmar
retirada**. Despacho exige escolher o entregador. A retirada exige o código de
6 dígitos apresentado pelo cliente no Darcapio, tanto nos cartões quanto nos
detalhes. Código vazio, incompleto ou incorreto não conclui o pedido; o operador
pode corrigir o código na mesma janela. O Service valida o código e mantém o
bloqueio após cinco tentativas incorretas. Food e Service precisam ser atualizados
juntos. Na entrega, o Food segue a exigência enviada pelo Service; o app do
entregador continua conferindo o código. O cancelamento das demais etapas
continua disponível nos detalhes. A dispensa `ExigeCodigo: false` é oferecida
somente para entregas na rota autenticada do Food.
Verificação: `flutter test test/food_order_card_actions_test.dart`.

O botão **Imprimir pedido**, ao lado do status nos detalhes, está disponível nos
dois canais. A impressão manual usa o mesmo cupom de 80 mm e o diálogo de
impressão do sistema. No Darcapio inclui a loja, itens, adicionais, observações,
pagamento, troco e endereço de entrega; retirada não imprime endereço.
Verificação: `flutter test test/order_receipt_test.dart test/food_order_details_design_test.dart test/food_orders_page_test.dart`.

“Aguardando aceite” contém apenas pedidos aguardando aceite. A modalidade
“Entrega no endereço” ou “Retirada na loja” aparece separada do status no cartão.
Pedidos prontos e pedidos que saíram para entrega ficam nas respectivas colunas,
atualizadas também quando a etapa muda fora do Food.

O pedido concluído pelo cliente no Darcapio é sincronizado uma única vez para o
ERP como um Delivery vinculado a uma pré-venda não faturada. O Food só o recebe
depois dessa confirmação. Aceite, preparo, pronto e conclusão atualizam as
etapas desse mesmo Delivery e retornam a situação ao Darcapio, sem criar outra
venda. A conclusão mantém o faturamento da venda vinculada executado pelo Service.

Configuração da fixture local: servidor `https://localhost:5943/arc`, empresa `1`
(Loja A) ou `2` (Loja B), terminal `91001` e usuário ERP `darcapio.local`, com a
senha local já configurada. O certificado HTTPS precisa ser confiável. O cliente
Darcapio não ignora erros TLS e não segue redirecionamentos. Fora de localhost,
HTTP sem TLS é rejeitado. A integração reutiliza o token do Food nas preferências
existentes; não lê nem armazena uma senha adicional.

O servidor exige sessão da aplicação Kronos Food 2 (9), empresa e permissões de
Delivery. As ações vêm em `AcoesPermitidas`, calculadas pelo Kronos Service,
incluindo entrega e retirada. O cliente envia o comando e a versão; a retirada
inclui `CodigoConfirmacao`, conferido no Service antes do faturamento. A entrega
pelo Food pode dispensar esse campo. O Service mantém as validações de
etapa, versão, empresa e privilégios e registra o operador no histórico.
Endereço, taxa e troco são exibidos no pedido. O código correto nunca vem na
listagem Food. Recusa/cancelamento exige motivo e permissão do servidor.

Verificação: `flutter test test/food_orders_page_test.dart test/food_login_test.dart test/darcapio_test.dart` e análise dos arquivos
`lib/repositories/darcapio_repository.dart` e `lib/pages/food_orders_view.dart`.
O relatório atualizado está em `E:/ARC-SOLUTION/docs/darcapio-entrega-admin-20260911.md`.

## Autenticação iFood

O ID da loja identifica o estabelecimento; a autenticação também depende das
credenciais e do tipo do aplicativo iFood. Configure `IFOOD_CLIENT_ID` na
compilação. No Windows, instale o segredo no Gerenciador de Credenciais do
usuário, como credencial genérica `KronosFood/iFood/<clientId>`, com o Client ID
como usuário e o segredo como conteúdo UTF-16. A build pode ser gerada sem
`IFOOD_CLIENT_SECRET`; o suporte ao define anterior é mantido por compatibilidade.
Não inclua arquivos de credenciais ou tokens no pacote distribuído. A conexão
OAuth valida o certificado TLS e não segue redirecionamentos.

Para instalar a partir de uma `PSCredential` salva com `Export-Clixml`, execute
`tool/install_ifood_windows_credential.ps1 -CredentialXmlPath <arquivo-local>`
com o mesmo usuário que salvou o arquivo. Confira a leitura sem exibir o segredo
com `dart run tool/check_ifood_windows_credential.dart <clientId>`.

`IFOOD_AUTH_MODE=centralized` mantém o fluxo `client_credentials`. Para aplicativos
distribuídos, use `IFOOD_AUTH_MODE=distributed`: o primeiro acesso depende do
código autorizado no Portal do Parceiro. O código retornado pelo portal e o
verificador da mesma solicitação são trocados por tokens; informar somente o ID
da loja não realiza essa troca. Use **Conectar iFood** no painel de pedidos ou
no menu lateral para autorizar a loja. O Food mostra o código e o link do Portal,
recebe o código de autorização e salva os tokens sem alterar a sessão Kronos.
Se a autorização expirar ou for revogada, esse mesmo fluxo permite reconectar.

Para gerar a build Windows com o aplicativo e a loja de homologação, execute
`tool/build_ifood_homologacao.ps1`. O arquivo público
`config/ifood_homologacao.json` fixa o modo distribuído desse Client ID e não
contém o segredo; a credencial continua sendo instalada por usuário Windows.

Depois de salvar a autorização, o Food reutiliza o token válido e renova com
`refresh_token` quando ele está próximo de expirar. Consultas simultâneas
compartilham a renovação em andamento. Se o iFood não devolver outro refresh
token, o anterior é preservado. Não há fallback para `client_credentials` no
modo distribuído sem autorização.

Verificação: `flutter test test/ifood_auth_repository_test.dart test/ifood_connection_test.dart test/food_login_test.dart`.

## Integração iFood — requisitos anteriores

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
