import 'dart:convert';

class AnonymizationService {
  static String normalize(String name) => name.trim().toUpperCase();

  static int hash(String normalizedName) {
    int h = 0x811c9dc5;
    for (final b in utf8.encode(normalizedName)) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static String hexCode(int h) =>
      (h & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
}
