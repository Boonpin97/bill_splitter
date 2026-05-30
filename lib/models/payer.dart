import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Payer {
  Payer({String? id, required this.name}) : id = id ?? _uuid.v4();

  final String id;
  String name;
}
