
# TicketsPrinter

Aplicativo Flutter para venda de tickets com impressão via Bluetooth.

## Funcionalidades
- Cadastro, edição e ativação/desativação de tickets (produtos).
- Venda de tickets: seleção de quantidade, impressão e registro da venda.
- Impressão via impressora Bluetooth (Blue Thermal Printer).
- Relatório de vendas com impressão direta.
- Seleção e teste de impressora Bluetooth nas configurações.
- Banco de dados local SQLite (sqflite).
- Interface simples e responsiva.

## Instalação
1. **Clone o repositório:**
	```
	git clone https://github.com/guilhermedambros/poc_flutter_tickets.git
	```
2. **Acesse a pasta do projeto:**
	```
	cd poc_flutter_tickets
	```
3. **Instale as dependências:**
	```
	flutter pub get
	```
4. **Gere os ícones do app:**
	```
	flutter pub run flutter_launcher_icons:main
	```
5. **Execute o app:**
	```
	flutter run
	```

## Configuração do ícone do app
O ícone do aplicativo está em `assets/images/app_icon.png` e é gerado automaticamente pelo `flutter_launcher_icons`.

## Estrutura do Banco de Dados
- **tickets**: id, description, active, created_at
- **vendas**: id, ticket_id, amount, created_at

## Principais Dependências
- [sqflite](https://pub.dev/packages/sqflite)
- [blue_thermal_printer](https://pub.dev/packages/blue_thermal_printer)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)

## Observações
- Para impressão, é necessário parear a impressora Bluetooth previamente no sistema operacional.
- O app foi desenvolvido para Android, mas pode ser adaptado para outras plataformas.

## Licença
Este projeto é open source, sob a licença MIT.
