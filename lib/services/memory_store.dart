import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MemoryFact {
  const MemoryFact({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory MemoryFact.fromJson(Map<String, dynamic> json) => MemoryFact(
        id: json['id'] as String? ?? 'fact',
        text: json['text'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// Long-term facts Emo keeps about its boss. Stored on the phone only.
class MemoryStore {
  static const _key = 'emo.memory.v1';
  static const maxFacts = 50;
  static const maxFactLength = 200;

  SharedPreferences? _prefs;
  List<MemoryFact> facts = [];

  bool get isEmpty => facts.isEmpty;
  int get count => facts.length;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    facts = [];
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final fact = MemoryFact.fromJson(Map<String, dynamic>.from(item));
        if (fact.text.trim().isNotEmpty) facts.add(fact);
      }
    } catch (_) {
      facts = [];
    }
  }

  bool knows(String text) {
    final clean = _clean(text).toLowerCase();
    if (clean.isEmpty) return false;
    return facts.any((fact) => fact.text.toLowerCase() == clean);
  }

  /// Returns false when the fact is empty or already known.
  Future<bool> add(String text, {DateTime? now}) async {
    final clean = _clean(text);
    if (clean.isEmpty) return false;
    if (knows(clean)) return false;
    final moment = now ?? DateTime.now();
    facts.add(
      MemoryFact(
        id: 'm-${moment.microsecondsSinceEpoch}',
        text: clean,
        createdAt: moment,
      ),
    );
    while (facts.length > maxFacts) {
      facts.removeAt(0);
    }
    await _persist();
    return true;
  }

  Future<bool> remove(String id) async {
    final before = facts.length;
    facts.removeWhere((fact) => fact.id == id);
    if (facts.length == before) return false;
    await _persist();
    return true;
  }

  /// Forgets every fact mentioning [text]; returns how many were removed.
  Future<int> forget(String text) async {
    final needle = _clean(text).toLowerCase();
    if (needle.isEmpty) return 0;
    final before = facts.length;
    facts.removeWhere(
      (fact) =>
          fact.text.toLowerCase().contains(needle) ||
          needle.contains(fact.text.toLowerCase()),
    );
    final removed = before - facts.length;
    if (removed > 0) await _persist();
    return removed;
  }

  Future<void> clear() async {
    if (facts.isEmpty) return;
    facts = [];
    await _persist();
  }

  String get promptBlock =>
      facts.isEmpty ? '- nothing saved yet' : facts.map((f) => '- ${f.text}').join('\n');

  String _clean(String text) {
    var clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    clean = clean.replaceFirst(RegExp(r'^that\s+', caseSensitive: false), '');
    clean = clean.replaceFirst(RegExp(r'[.!?]+$'), '').trim();
    if (clean.length > maxFactLength) {
      clean = clean.substring(0, maxFactLength).trim();
    }
    return clean;
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _key,
        jsonEncode(facts.map((fact) => fact.toJson()).toList()),
      );
    } catch (_) {}
  }
}
