const vehicleSizes = ['motorcycle', 'small', 'medium', 'large', 'truck'];

class SizeRate {
  final String label;
  final double ratePerBlock;
  SizeRate(this.label, this.ratePerBlock);
  factory SizeRate.fromJson(Map<String, dynamic> j) => SizeRate(j['label'] as String, (j['ratePerBlock'] as num).toDouble());
}

class RateConfig {
  final int blockHours;
  final int graceMinutes;
  final double overstayHours;
  final int longStayDays;
  final int longStayBlockHours;
  final Map<String, SizeRate> sizes;
  RateConfig(this.blockHours, this.graceMinutes, this.sizes, {this.overstayHours = 6, this.longStayDays = 7, this.longStayBlockHours = 24});
  factory RateConfig.fromJson(Map<String, dynamic> j) => RateConfig(
        (j['blockHours'] as num).toInt(),
        (j['graceMinutes'] as num).toInt(),
        (j['sizes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, SizeRate.fromJson(v as Map<String, dynamic>))),
        overstayHours: ((j['overstayHours'] ?? 6) as num).toDouble(),
        longStayDays: ((j['longStayDays'] ?? j['bikeLongStayDays'] ?? 7) as num).toInt(),
        longStayBlockHours: ((j['longStayBlockHours'] ?? j['bikeLongStayBlockHours'] ?? 24) as num).toInt(),
      );
}

class Lot {
  final String id, name, address;
  final int capacity;
  final RateConfig rates;
  Lot(this.id, this.name, this.address, this.capacity, this.rates);
  factory Lot.fromJson(Map<String, dynamic> j) => Lot(
        j['id'] as String,
        j['name'] as String,
        (j['address'] ?? '') as String,
        (j['capacity'] as num).toInt(),
        RateConfig.fromJson(j['rates'] as Map<String, dynamic>),
      );
}

class ParkSession {
  final String id, lotId, plate, size, status;
  final DateTime entryAt;
  final DateTime? exitAt;
  final num? amount;
  final int? minutes;
  final String? ownerName, ownerPhone, paymentMethod;
  final bool hasPhoto;
  final RateConfig? rates;
  final bool pending; // saved on this phone, not yet sent to the server

  ParkSession({
    required this.id,
    required this.lotId,
    required this.plate,
    required this.size,
    required this.status,
    required this.entryAt,
    this.exitAt,
    this.amount,
    this.minutes,
    this.ownerName,
    this.ownerPhone,
    this.paymentMethod,
    this.hasPhoto = false,
    this.rates,
    this.pending = false,
  });

  /// This record as a finished stay (used while a check-out is waiting to be sent).
  ParkSession asExited({required DateTime exitAt, required num amount, required int minutes}) => ParkSession(
        id: id,
        lotId: lotId,
        plate: plate,
        size: size,
        status: 'exited',
        entryAt: entryAt,
        exitAt: exitAt,
        amount: amount,
        minutes: minutes,
        ownerName: ownerName,
        ownerPhone: ownerPhone,
        paymentMethod: 'cash',
        hasPhoto: hasPhoto,
        rates: rates,
        pending: true,
      );

  String get sizeLabel => rates?.sizes[size]?.label ?? size;

  factory ParkSession.fromJson(Map<String, dynamic> j) => ParkSession(
        id: j['id'] as String,
        lotId: j['lotId'] as String,
        plate: j['plate'] as String,
        size: j['size'] as String,
        status: j['status'] as String,
        entryAt: DateTime.parse(j['entryAt'] as String).toLocal(),
        exitAt: j['exitAt'] == null ? null : DateTime.parse(j['exitAt'] as String).toLocal(),
        amount: j['amount'] as num?,
        minutes: (j['minutes'] as num?)?.toInt(),
        ownerName: j['ownerName'] as String?,
        ownerPhone: j['ownerPhone'] as String?,
        paymentMethod: j['paymentMethod'] as String?,
        hasPhoto: (j['hasPhoto'] ?? false) as bool,
        rates: j['rates'] == null ? null : RateConfig.fromJson(j['rates'] as Map<String, dynamic>),
      );
}

class Quote {
  final int minutes, blocks;
  final num ratePerBlock, amount;
  final DateTime nextIncreaseAt;
  Quote(this.minutes, this.blocks, this.ratePerBlock, this.amount, this.nextIncreaseAt);
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        (j['minutes'] as num).toInt(),
        (j['blocks'] as num).toInt(),
        j['ratePerBlock'] as num,
        j['amount'] as num,
        DateTime.parse(j['nextIncreaseAt'] as String).toLocal(),
      );
}
