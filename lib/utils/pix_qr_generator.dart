import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class PixPayloadResult {
  final String payload;
  final String txid;
  
  PixPayloadResult({required this.payload, required this.txid});
}

class PixQrGenerator {
  /// Gera o payload Pix Copia e Cola manualmente seguindo padrão EMV
  /// Retorna tanto o payload quanto o txid gerado
  static PixPayloadResult generatePayloadWithTxid({
    required String chave,
    required double valor,
    String? nome,
    String? cidade,
    String? descricao,
    DateTime? vencimento,
  }) {
    print('[PIX PAYLOAD] Iniciando geração...');
    
    // Validações de entrada
    if (chave.isEmpty) {
      throw Exception('Chave PIX vazia');
    }
    if (valor <= 0) {
      throw Exception('Valor deve ser maior que zero');
    }
    
    // Validar chave Pix
    String chaveFormatada = _formatarChavePix(chave);
    
    // Implementação manual do Pix Copia e Cola
    nome = _sanitizeText(nome ?? 'Empresa', 25);
    cidade = _sanitizeText(cidade ?? 'BRASIL', 15);
    descricao = _sanitizeText(descricao ?? '', 25);
    
    if (nome.isEmpty) {
      throw Exception('Nome não pode ser vazio após sanitização');
    }
    if (cidade.isEmpty) {
      throw Exception('Cidade não pode ser vazia após sanitização');
    }
    
    // Gera um identificador único para a transação com timestamp + componente aleatório
    // Limita a 25 caracteres conforme especificação Pix
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    String txId = 'TKT${timestamp}$random';
    
    // Garantir que o TXID não ultrapasse 25 caracteres
    if (txId.length > 25) {
      txId = txId.substring(0, 25);
    }
    
    print('[PIX PAYLOAD] TXID gerado: $txId (${txId.length} caracteres)');
    
    // Formato EMV padrão para Pix
    String payload = '';
    
    // Payload Format Indicator
    payload += _formatTLV('00', '01');
    
    // Point of Initiation Method (11 = reutilizável, 12 = único)
    payload += _formatTLV('01', '12');
    
    // Merchant Account Information - Pix
    String pixInfo = '';
    pixInfo += _formatTLV('00', 'BR.GOV.BCB.PIX');
    pixInfo += _formatTLV('01', chaveFormatada);
    if (descricao.isNotEmpty) {
      pixInfo += _formatTLV('02', descricao);
    }
    payload += _formatTLV('26', pixInfo);
    
    // Merchant Category Code
    payload += _formatTLV('52', '0000');
    
    // Transaction Currency (986 = Real brasileiro)
    payload += _formatTLV('53', '986');
    
    // Transaction Amount
    payload += _formatTLV('54', valor.toStringAsFixed(2));
    
    // Country Code
    payload += _formatTLV('58', 'BR');
    
    // Merchant Name
    payload += _formatTLV('59', nome);
    
    // Merchant City
    payload += _formatTLV('60', cidade);
    
    // Postal Code (opcional)
    // payload += _formatTLV('61', '00000000');
    
    // Additional Data Field Template (obrigatório)
    String additionalData = '';
    additionalData += _formatTLV('05', txId); // Reference Label (identificador)
    if (descricao.isNotEmpty) {
      additionalData += _formatTLV('02', descricao); // Bill Number
    }
    // Se houver vencimento, adiciona
    if (vencimento != null) {
      String dataVenc = DateFormat('yyyyMMdd').format(vencimento);
      additionalData += _formatTLV('07', dataVenc); // Due Date
    }
    payload += _formatTLV('62', additionalData);
    
    // CRC16
    payload += '6304';
    String crc = _calculateCRC16(payload);
    payload += crc;
    
    // Debug: imprimir início do payload para validação
    print('[PIX PAYLOAD] Início do payload: ${payload.substring(0, payload.length > 20 ? 20 : payload.length)}');
    
    // Validar se o payload foi gerado corretamente
    // O payload deve começar com "000201" (Payload Format Indicator)
    if (payload.isEmpty || !payload.startsWith('000201')) {
      print('[PIX PAYLOAD] ERRO: Payload inválido. Início esperado: "000201", Recebido: "${payload.substring(0, payload.length > 10 ? 10 : payload.length)}"');
      throw Exception('Payload PIX inválido gerado');
    }
    
    print('[PIX PAYLOAD] ========================================');
    print('[PIX PAYLOAD] Payload Pix gerado com sucesso');
    print('[PIX PAYLOAD] Chave: $chaveFormatada');
    print('[PIX PAYLOAD] Valor: R\$ ${valor.toStringAsFixed(2)}');
    print('[PIX PAYLOAD] Nome: $nome');
    print('[PIX PAYLOAD] Cidade: $cidade');
    print('[PIX PAYLOAD] TX ID: $txId');
    if (vencimento != null) {
      print('[PIX PAYLOAD] Vencimento: ${DateFormat('dd/MM/yyyy').format(vencimento)}');
    }
    print('[PIX PAYLOAD] CRC: $crc');
    print('[PIX PAYLOAD] Tamanho total: ${payload.length} caracteres');
    print('[PIX PAYLOAD] Primeiros 50 caracteres: ${payload.substring(0, payload.length > 50 ? 50 : payload.length)}...');
    print('[PIX PAYLOAD] ========================================');
    
    return PixPayloadResult(payload: payload, txid: txId);
  }

  /// Gera o payload Pix Copia e Cola manualmente seguindo padrão EMV
  /// Método mantido para compatibilidade
  static String generatePayload({
    required String chave,
    required double valor,
    String? nome,
    String? cidade,
    String? descricao,
    DateTime? vencimento,
  }) {
    return generatePayloadWithTxid(
      chave: chave,
      valor: valor,
      nome: nome,
      cidade: cidade,
      descricao: descricao,
      vencimento: vencimento,
    ).payload;
  }
  
  /// Formatar chave Pix (remover formatação se for CNPJ/CPF)
  static String _formatarChavePix(String chave) {
    // Remove pontos, traços, barras e espaços
    String chaveFormatada = chave.replaceAll(RegExp(r'[.\-/\s]'), '');
    
    print('Chave original: $chave');
    print('Chave formatada: $chaveFormatada');
    
    // Valida se é um CNPJ (14 dígitos) ou CPF (11 dígitos)
    if (chaveFormatada.length == 14 || chaveFormatada.length == 11) {
      if (RegExp(r'^\d+$').hasMatch(chaveFormatada)) {
        return chaveFormatada;
      }
    }
    
    // Se não for CPF/CNPJ, assume que é email ou telefone
    return chave;
  }
  
  /// Sanitiza texto removendo acentos e limitando tamanho
  static String _sanitizeText(String text, int maxLength) {
    String sanitized = text
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ''); // Remove caracteres especiais
    
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    return sanitized;
  }
  
  /// Formata campo TLV (Tag-Length-Value)
  static String _formatTLV(String tag, String value) {
    int length = utf8.encode(value).length;
    return tag + length.toString().padLeft(2, '0') + value;
  }
  
  /// Calcula CRC16 para validação do payload
  static String _calculateCRC16(String data) {
    List<int> bytes = utf8.encode(data);
    int crc = 0xFFFF;
    
    for (int byte in bytes) {
      crc ^= byte << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = crc << 1;
        }
        crc &= 0xFFFF;
      }
    }
    
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Retorna um widget QR Code para o payload Pix
  static Widget buildQrCode(String payload, {double size = 180}) {
    return QrImageView(
      data: payload,
      version: QrVersions.auto,
      size: size,
      gapless: false,
      errorStateBuilder: (cxt, err) => const Center(child: Text('Erro ao gerar QR Code')),
    );
  }
}