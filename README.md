
# 🎫 TicketsPrinter - Sistema de Vendas com Pix

Aplicativo Flutter completo para venda de tickets com impressão térmica Bluetooth e pagamento via Pix.

## 🚀 Funcionalidades Principais

### 📊 **Gestão de Produtos**
- ✅ Cadastro, edição e exclusão de tickets (produtos)
- ✅ Ativação/desativação de produtos
- ✅ Ícones personalizáveis para cada produto (40+ opções)
- ✅ Controle de preços e descrições
- ✅ Ordenação alfabética automática

### 💰 **Sistema de Vendas**
- ✅ Interface intuitiva para seleção de produtos
- ✅ Controle de quantidades por produto
- ✅ Cálculo automático de totais
- ✅ Registro completo de vendas no banco de dados
- ✅ Impressão automática de tickets individuais

### 🖨️ **Impressão Térmica**
- ✅ Conexão Bluetooth com impressoras térmicas
- ✅ Configuração de tamanhos de fonte (descrição, valor, hora)
- ✅ Impressão de tickets formatados
- ✅ Teste automático de impressão ao conectar
- ✅ QR Code Pix impresso automaticamente (250x250px)

### 💳 **Sistema Pix Completo**
- ✅ Geração de QR Code Pix seguindo padrão EMV do Banco Central
- ✅ Configuração completa: chave, nome, cidade, descrição
- ✅ TXID único para cada transação
- ✅ Vencimento automático (24 horas)
- ✅ Validação de chaves Pix (CPF, CNPJ, email, telefone)
- ✅ QR Code válido para todos os bancos

### 📱 **Interface de Usuário**
- ✅ Design responsivo e moderno
- ✅ Navegação por abas organizadas
- ✅ Página de configurações com 3 seções:
  - 🖨️ **Impressora**: Bluetooth + Configurações de fonte
  - 💰 **Pix**: Dados de pagamento
  - 💾 **Dados**: Gerenciamento e backup
- ✅ Controle de estado inteligente (botão desabilitado durante QR Code)
- ✅ Feedback visual completo

### 📊 **Relatórios e Consultas**
- ✅ Consulta de vendas por TXID
- ✅ Visualização da última venda
- ✅ Eliminação seletiva de vendas por data
- ✅ Relatório completo de vendas com impressão
- ✅ Backup e restauração de dados

## 🛠️ Tecnologias Utilizadas

### **Backend/Banco de Dados**
- **SQLite** (sqflite) - Banco local com migração automática
- **SharedPreferences** - Configurações persistentes

### **Funcionalidades Específicas**
- **blue_thermal_printer** - Impressão Bluetooth
- **qr_flutter** - Geração de QR Codes
- **intl** - Formatação de datas e valores

### **Interface**
- **Material Design** - Interface nativa Android
- **TabController** - Navegação por abas
- **SingleChildScrollView** - Scroll responsivo

## 🗃️ Estrutura do Banco de Dados

### **Tabela: tickets**
```sql
CREATE TABLE tickets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  description VARCHAR(100) NOT NULL,
  valor REAL NOT NULL DEFAULT 0,
  icon VARCHAR(50) DEFAULT 'local_activity',
  active INTEGER NOT NULL DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
```

### **Tabela: vendas**
```sql
CREATE TABLE vendas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ticket_id INTEGER NOT NULL,
  amount INTEGER,
  valor_unitario REAL NOT NULL DEFAULT 0,
  txid VARCHAR(255), -- ID da transação Pix
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(ticket_id) REFERENCES tickets(id)
)
```

## 🔧 Instalação e Configuração

### **1. Clone o repositório:**
```bash
git clone https://github.com/guilhermedambros/poc_flutter_tickets.git
cd poc_flutter_tickets
```

### **2. Instale as dependências:**
```bash
flutter pub get
```

### **3. Configure o ícone do app:**
```bash
flutter pub run flutter_launcher_icons:main
```

### **4. Execute o app:**
```bash
flutter run
```

## ⚙️ Configuração do Sistema

### **🖨️ Impressora Bluetooth**
1. Pareie a impressora térmica no Android
2. Abra Configurações → Aba "Impressora"
3. Selecione a impressora na lista
4. Teste a conexão (impressão automática)

### **💰 Configuração Pix**
1. Abra Configurações → Aba "Pix"
2. Configure:
   - **Chave Pix**: CPF, CNPJ, telefone, email ou chave aleatória
   - **Nome**: Nome do recebedor
   - **Cidade**: Cidade do estabelecimento
   - **Descrição**: Descrição padrão dos pagamentos
3. Salve as configurações

### **🎨 Personalização de Fontes**
1. Configurações → Aba "Impressora" → Seção "Tamanhos de Fonte"
2. Ajuste tamanhos para:
   - Descrição do produto
   - Valor do produto  
   - Data e hora

## 📋 Principais Dependências

```yaml
dependencies:
  flutter: sdk: flutter
  sqflite: ^2.3.0              # Banco de dados local
  blue_thermal_printer: ^1.2.4  # Impressão Bluetooth
  shared_preferences: ^2.2.2    # Configurações
  qr_flutter: ^4.1.0           # QR Code
  intl: ^0.19.0                 # Formatação
  
dev_dependencies:
  flutter_launcher_icons: ^0.13.1  # Ícone do app
```

## 🎯 Funcionalidades Avançadas

### **💡 QR Code Pix Inteligente**
- ✅ Geração manual seguindo especificação EMV
- ✅ CRC16 para validação
- ✅ Campos TLV formatados corretamente
- ✅ TXID único por transação
- ✅ Vencimento configurável

### **🔒 Controle de Estado**
- ✅ Botão "Imprimir" desabilitado durante QR Code ativo
- ✅ Limpeza automática de quantidades ao fechar QR Code
- ✅ Prevenção de múltiplas impressões simultâneas

### **📊 Rastreabilidade Completa**
- ✅ Cada venda possui TXID único
- ✅ Consulta de vendas por TXID
- ✅ Histórico completo de transações
- ✅ Backup seletivo por data

## 🎮 Como Usar

### **📦 Vendas**
1. Selecione produtos e quantidades
2. Clique em "Imprimir"
3. Tickets são impressos automaticamente
4. QR Code Pix é gerado e impresso
5. Cliente pode pagar escaneando o QR Code

### **⚙️ Configurações**
- **Impressora**: Configure conexão Bluetooth e fontes
- **Pix**: Configure dados de recebimento
- **Dados**: Consulte vendas e faça backup

### **🔍 Consultas**
- **Última venda**: Ícone no AppBar da página de vendas
- **Por TXID**: Configurações → Dados → Consultar TXID
- **Relatório**: Menu principal → Relatórios

## 🚨 Requisitos do Sistema

- **Android 5.0+** (API level 21+)
- **Bluetooth** para impressora térmica
- **Impressora térmica** compatível com ESC/POS
- **Conexão com internet** (opcional, para validação de chaves Pix)

## 📝 Observações Importantes

- **Impressora**: Deve ser pareada no Android antes do uso
- **QR Code**: Máximo 250x250px para impressoras térmicas
- **Pix**: Chaves são validadas automaticamente
- **Backup**: Funcionalidade de reset completo disponível
- **Migração**: Banco atualiza automaticamente entre versões

## 🆔 Versão Atual
- **Versão do Banco**: 3.0 (com suporte a TXID)
- **Compatibilidade**: Migração automática de versões anteriores
- **Última atualização**: Outubro 2025

## 📄 Licença
Este projeto é open source, sob a licença MIT.

---
*Desenvolvido para PDAs Android com impressoras térmicas Bluetooth*
