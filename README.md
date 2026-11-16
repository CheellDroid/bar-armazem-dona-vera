# Bar e Armazém Dona Vera — base inicial 1.0

Projeto Flutter para Android com interface colorida e banco SQLite local.

## Incluído nesta primeira base
- Painel financeiro: total vendido, recebido, fiado aberto, despesas e lucro estimado.
- Cadastro de produtos: custo, preço de venda e estoque inicial.
- Cadastro de clientes.
- Registro de venda de um produto por lançamento.
- Venda à vista ou parcialmente paga/fiado.
- Data de vencimento opcional.
- Registro de pagamentos parciais.
- Registro de despesas.
- Banco local SQLite e funcionamento offline.

## Ainda não implementado
A sincronização automática entre os dois celulares e o backup em nuvem NÃO estão ativos nesta versão. Cada aparelho terá seu próprio banco local até configurarmos um serviço compartilhado, pareamento e política de conflitos. Não use esta versão como única cópia dos dados reais.

## Compilar no Windows
1. Instale Flutter SDK e Android Studio com Android SDK.
2. Extraia o ZIP.
3. Abra PowerShell na pasta do projeto e execute:
   `flutter pub get`
   `flutter run`
4. Para gerar APK:
   `flutter build apk --release`
5. O APK estará em `build\app\outputs\flutter-apk\app-release.apk`.

## Observações financeiras
O lucro estimado é total vendido menos custo dos itens vendidos e despesas registradas. O fiado entra no total vendido, mas não no total recebido. O estoque é reduzido ao registrar a venda, sem permitir estoque negativo.

## Próxima etapa
Adicionar carrinho com vários itens, edição/exclusão segura, extrato por cliente, relatórios por período, exportação/backup e sincronização bidirecional com nuvem.
