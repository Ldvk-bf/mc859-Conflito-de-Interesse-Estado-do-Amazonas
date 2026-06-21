import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/conflito_record.dart';

class CsvParserService {
  static const _assetPath = 'assets/data/conflito_de_interesse_full.csv';

  Future<List<ConflittoRecord>> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) return [];

    final records = <ConflittoRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 19) continue;
      try {
        records.add(ConflittoRecord.fromRow(i - 1, row));
      } catch (_) {
        // skip malformed rows
      }
    }
    return records;
  }
}
