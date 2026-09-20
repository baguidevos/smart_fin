/// SamaFi — utilitaires de formatage (français, devise FCFA).
///
/// Le FCFA (XOF) n'a pas de subdivision usuelle : tous les montants sont des
/// entiers. Format : `42 000 FCFA` (séparateur fin, symbole après).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _fcfaFmt = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'FCFA',
  decimalDigits: 0,
);

/// `42000` → `42 000 FCFA`
String fcfa(num value) => _fcfaFmt.format(value);

/// `42000` → `+42 000 FCFA` / `-42000` → `-42 000 FCFA`
String fcfaSigned(num value) =>
    "${value >= 0 ? '+' : '-'}${_fcfaFmt.format(value.abs())}";

/// Format compact pour les graphiques : `42 k`, `1,2 M`.
String fcfaCompact(num value) {
  final v = value.abs();
  String trim(String s) => s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  if (v >= 1000000) return '${trim((v / 1000000).toStringAsFixed(1).replaceAll('.', ','))} M';
  if (v >= 1000) return '${trim((v / 1000).toStringAsFixed(1).replaceAll('.', ','))} k';
  return value.toInt().toString();
}

/// `5` → `05`
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// `2024-06-08` → `8 juin`
String dateShort(DateTime d) => DateFormat('d MMM', 'fr_FR').format(d);

/// `2024-06-08` → `sam. 8 juin`
String dateMedium(DateTime d) => DateFormat('EEE d MMM', 'fr_FR').format(d);

/// `2024-06-08` → `samedi 8 juin 2024`
String dateFull(DateTime d) => DateFormat('EEEE d MMMM y', 'fr_FR').format(d);

/// `2024-06-08` → `8 juin 2024` (en-têtes de groupes de l'historique)
String dayLabel(DateTime d) => DateFormat('d MMMM y', 'fr_FR').format(d);

/// `2024-06-08` → `juin 2024`
String monthYear(DateTime d) => DateFormat('MMMM y', 'fr_FR').format(d);

/// Date au format `jj/mm/aaaa` pour les champs de formulaire.
String dateField(DateTime? d) =>
    d == null ? '' : "${twoDigits(d.day)}/${twoDigits(d.month)}/${d.year}";

/// Parse `jj/mm/aaaa` ou `aaaa-mm-jj` (retourne null si invalide).
DateTime? parseDateField(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m != null) {
    final d = DateTime.tryParse(
        '${m.group(3)}-${twoDigits(int.parse(m.group(2)!))}-${twoDigits(int.parse(m.group(1)!))}');
    return d;
  }
  return DateTime.tryParse(s);
}

/// `#059669` → `Color(0xFF059669)` (avec repli émeraude).
Color hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? const Color(0xFF059669) : Color(value);
}

/// Aujourd'hui moins [days] jours, à midi (évite les décalages d'heures d'été).
DateTime daysAgo(int days) =>
    DateTime.now().subtract(Duration(days: days));

/// Aujourd'hui plus [days] jours.
DateTime daysFromNow(int days) => DateTime.now().add(Duration(days: days));

/// Analyse une saisie de montant FCFA (`"12 500"` → `12500`), null si invalide.
int? parseAmount(String raw) {
  final cleaned =
      raw.replaceAll(RegExp(r'[\s\u00A0\u202F.]'), '').replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned);
}
