import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum ChargeMode { inclusive, exclusive }

enum ChargeKind { gst, serviceCharge, discount, other }

class Charge {
  Charge({
    required this.kind,
    required this.mode,
    this.percent,
    this.amount,
    this.label,
  });

  final ChargeKind kind;
  ChargeMode mode;
  double? percent;
  double? amount;
  final String? label;

  String displayName() {
    if (label != null && label!.isNotEmpty) return label!;
    switch (kind) {
      case ChargeKind.gst:
        return 'GST';
      case ChargeKind.serviceCharge:
        return 'Service charge';
      case ChargeKind.discount:
        return 'Discount';
      case ChargeKind.other:
        return 'Other';
    }
  }

  Charge copyWith({ChargeMode? mode, double? percent, double? amount}) =>
      Charge(
        kind: kind,
        mode: mode ?? this.mode,
        percent: percent ?? this.percent,
        amount: amount ?? this.amount,
        label: label,
      );

  factory Charge.fromJson(Map<String, dynamic> json) {
    final kindStr = (json['kind'] as String?)?.toLowerCase() ?? 'other';
    final modeStr = (json['mode'] as String?)?.toLowerCase() ?? 'exclusive';
    return Charge(
      kind: switch (kindStr) {
        'gst' || 'tax' || 'vat' => ChargeKind.gst,
        'service' ||
        'service_charge' ||
        'servicecharge' => ChargeKind.serviceCharge,
        'discount' => ChargeKind.discount,
        _ => ChargeKind.other,
      },
      mode: modeStr == 'inclusive'
          ? ChargeMode.inclusive
          : ChargeMode.exclusive,
      percent: (json['percent'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      label: json['label'] as String?,
    );
  }
}

class LineItem {
  LineItem({
    String? id,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
  }) : id = id ?? _uuid.v4();

  final String id;
  String name;
  double unitPrice;
  int quantity;

  double get lineTotal => unitPrice * quantity;

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    name: (json['name'] as String?) ?? 'Item',
    unitPrice:
        (json['unitPrice'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class Receipt {
  Receipt({
    required this.currency,
    required this.items,
    required this.charges,
    required this.subtotal,
    required this.total,
  });

  final String currency;
  final List<LineItem> items;
  final List<Charge> charges;
  double subtotal;
  double total;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final items = ((json['items'] as List?) ?? const [])
        .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final charges = ((json['charges'] as List?) ?? const [])
        .map((e) => Charge.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Receipt(
      currency: (json['currency'] as String?) ?? 'SGD',
      items: items,
      charges: charges,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
