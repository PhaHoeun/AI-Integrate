class InvoiceModel {
  final String invoiceNo;
  final String supplier;
  final String supplierAddress;
  final String date;
  final String postingDate;
  final String dueDate;
  final String currency;
  final double subtotal;
  final double tax;
  final double discount;
  final double discountPercent;
  final double total;
  final String inWords;
  final List<InvoiceItem> items;

  InvoiceModel({
    required this.invoiceNo,
    required this.supplier,
    required this.supplierAddress,
    required this.date,
    required this.postingDate,
    required this.dueDate,
    required this.currency,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.discountPercent,
    required this.total,
    required this.inWords,
    required this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      invoiceNo: json['invoice_no'] ?? '',
      supplier: json['supplier'] ?? '',
      supplierAddress: json['supplier_address'] ?? json['address'] ?? '',
      date: json['date'] ?? '',
      postingDate: json['posting_date'] ?? json['date'] ?? '',
      dueDate: json['due_date'] ?? '',
      currency: json['currency'] ?? 'USD',
      subtotal: _parseDouble(json['subtotal']),
      tax: _parseDouble(json['tax']),
      discount: _parseDouble(json['discount']),
      discountPercent: _parseDouble(json['discount_percent']),
      total: _parseDouble(json['total']),
      inWords: json['in_words'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => InvoiceItem.fromJson(e))
          .toList(),
    );
  }

  /// Returns a display-friendly currency symbol when possible.
  String get currencySymbol {
    final code = currency.trim().toUpperCase();
    switch (code) {
      case 'USD':
      case '\$':
        return '\$';
      case 'EUR':
      case '€':
        return '€';
      case 'GBP':
      case '£':
        return '£';
      case 'JPY':
      case '¥':
        return '¥';
      case 'INR':
      case '₹':
        return '₹';
      default:
        // Fallback to the code if it's short, otherwise empty string
        if (code.length <= 3 && code.isNotEmpty) return code;
        return '';
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class InvoiceItem {
  final String name;
  final double qty;
  final double price;
  final double amount;

  InvoiceItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.amount,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      name: json['name'] ?? '',
      qty: (json['qty'] ?? 0).toDouble(),
      price: (json['price'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}
