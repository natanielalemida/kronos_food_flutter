import 'dart:convert';
import 'dart:typed_data';

/// Visual identity of the selected ERP company. Never contains session data.
class FoodStoreIdentity {
  final int company;
  final String name;
  final Uint8List? logo;
  const FoodStoreIdentity({required this.company, this.name = '', this.logo});

  factory FoodStoreIdentity.fromJson(Map<String, dynamic> json) {
    dynamic field(String key) {
      for (final entry in json.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
      }
      return null;
    }

    Uint8List? logo;
    final raw = field('imgLogo');
    try {
      if (raw is String && raw.isNotEmpty && raw.length <= 6 * 1024 * 1024) {
        logo = base64Decode(raw);
      } else if (raw is List &&
          raw.isNotEmpty &&
          raw.length <= 4 * 1024 * 1024 &&
          raw.every((value) => value is int && value >= 0 && value <= 255)) {
        logo = Uint8List.fromList(raw.cast<int>());
      }
    } on FormatException {
      // A missing or invalid logo must never prevent order handling.
    }
    return FoodStoreIdentity(
      company: int.tryParse(field('codigo').toString()) ?? 0,
      name: (field('nomeFantasia') ?? field('razaoSocial') ?? '')
          .toString()
          .trim(),
      logo: logo?.isEmpty == true ? null : logo,
    );
  }
}
