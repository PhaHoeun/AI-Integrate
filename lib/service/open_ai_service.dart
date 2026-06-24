import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class GeminiService {
  final Dio dio = Dio();

  // Provide the key at build/run time, for example:
  // flutter run --dart-define=GOOGLE_API_KEY=your_key_here
  static const apiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: 'AQ.Ab8RN6I4w8bSWbvFJ1-enN9c7GANxbiyrYk_2waDRHD5q-TTKA',
  );

  Future<Map<String, dynamic>> scanInvoice(File image) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'GOOGLE_API_KEY not set. Provide it via --dart-define or a secure secret manager.',
      );
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    const maxRetries = 5;
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await dio.post(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
          data: {
            "contents": [
              {
                "role": "user",
                "parts": [
                  {
                    "text": """
You are an invoice OCR AI.

Extract data from this invoice image.

Return ONLY valid JSON:

{
  "invoice_no": "Invoice/PO number",
  "supplier": "Supplier/Company name",
  "supplier_address": "Supplier address if available",
  "posting_date": "Date invoice was posted (YYYY-MM-DD)",
  "date": "Invoice date (YYYY-MM-DD)",
  "due_date": "Due date (YYYY-MM-DD)",
  "currency": "Currency code (USD, EUR, INR, etc.)",
  "subtotal": 0,
  "tax": 0,
  "discount": 0,
  "discount_percent": 0,
  "total": 0,
  "in_words": "Total amount in words",
  "items": [
    {
      "name": "Item description",
      "qty": 0,
      "price": 0,
      "amount": 0
    }
  ]
}

Rules:
- Extract exact values from the invoice
- For dates use YYYY-MM-DD format
- If missing value use empty string or 0
- Calculate amounts if not shown: amount = qty * price
- Do NOT explain or add comments
- Return ONLY JSON, no other text
""",
                  },
                  {
                    "inline_data": {
                      "mime_type": "image/jpeg",
                      "data": base64Image,
                    },
                  },
                ],
              },
            ],
          },
        );

        final text = _safeReadResponseText(response);
        final cleaned = _extractJsonLike(text);
        try {
          return jsonDecode(cleaned) as Map<String, dynamic>;
        } catch (e) {
          throw FormatException(
            'Failed to decode JSON from model response.\nResponse snippet: ${_snippet(cleaned, 800)}',
          );
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 429 && attempt < maxRetries) {
          // Exponential backoff with jitter
          final backoffSeconds = (1 << (attempt - 1));
          final jitterMs = (DateTime.now().millisecondsSinceEpoch % 300);
          await Future.delayed(
            Duration(seconds: backoffSeconds, milliseconds: jitterMs),
          );
          continue; // retry
        }
        rethrow;
      }
    }
  }

  String _safeReadResponseText(Response response) {
    try {
      final cand = response.data["candidates"];
      if (cand is List && cand.isNotEmpty) {
        final content = cand[0]["content"];
        if (content is Map &&
            content["parts"] is List &&
            (content["parts"] as List).isNotEmpty) {
          return content["parts"][0]["text"].toString();
        }
      }
    } catch (_) {}
    // Fallback: try to stringify whole response
    return response.data.toString();
  }

  String _extractJsonLike(String text) {
    if (text.trim().isEmpty) return text;

    // Remove fenced code blocks ```json``` or ```
    var cleaned = text.replaceAll(
      RegExp(r'```(?:json)?\n?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll('```', '');

    cleaned = cleaned.trim();

    // If it already looks like JSON, return
    if (cleaned.startsWith('{') || cleaned.startsWith('[')) return cleaned;

    // Try to find the first balanced JSON object in the text
    final start = cleaned.indexOf('{');
    if (start == -1) return cleaned;

    var depth = 0;
    for (var i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (ch == '{') depth++;
      if (ch == '}') depth--;
      if (depth == 0) {
        final candidate = cleaned.substring(start, i + 1).trim();
        return candidate;
      }
    }

    // Couldn't find balanced braces — return cleaned text as last resort
    return cleaned;
  }

  String _snippet(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}...';
  }
}
