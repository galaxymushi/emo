import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'intent_contract.dart';
import 'memory_store.dart';
import 'persona.dart';

export 'intent_contract.dart' show CloudReply;

class CloudProvider {
  const CloudProvider({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.model,
    required this.keyUrl,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String endpoint;
  final String model;
  final String keyUrl;
  final bool isCustom;

  static const gemini = CloudProvider(
    id: 'gemini',
    name: 'Google Gemini',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    model: 'gemini-3.8-flash',
    keyUrl: 'https://aistudio.google.com/app/apikey',
  );

  static const openai = CloudProvider(
    id: 'openai',
    name: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    model: 'gpt-4o-mini',
    keyUrl: 'https://platform.openai.com/api-keys',
  );

  static const openrouter = CloudProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    model: 'google/gemini-3.8-flash',
    keyUrl: 'https://openrouter.ai/keys',
  );

  static const groq = CloudProvider(
    id: 'groq',
    name: 'Groq',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    model: 'llama-3.3-70b-versatile',
    keyUrl: 'https://console.groq.com/keys',
  );

  static const custom = CloudProvider(
    id: 'custom',
    name: 'Custom',
    endpoint: '',
    model: '',
    keyUrl: '',
    isCustom: true,
  );

  static const all = [gemini, openai, openrouter, groq, custom];

  static CloudProvider byId(String id) {
    for (final provider in all) {
      if (provider.id == id) return provider;
    }
    return gemini;
  }

  /// Models Google has retired; saved configs from older builds must not
  /// keep pointing at them.
  static const retiredModels = {
    'gemini-2.5-flash',
    'google/gemini-2.5-flash',
  };

  static String resolveModel(CloudProvider provider, String? saved) {
    final model = saved?.trim() ?? '';
    if (provider.isCustom) return model;
    if (model.isEmpty || retiredModels.contains(model)) return provider.model;
    return model;
  }
}

class CloudBrain {
  CloudBrain({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String apiKey = '';
  String endpoint = CloudProvider.gemini.endpoint;
  String model = CloudProvider.gemini.model;

  bool get configured =>
      apiKey.trim().isNotEmpty &&
      endpoint.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  void close() => _client.close();

  Future<CloudReply> interpret({
    required String text,
    required DeviceState device,
    required List<Routine> routines,
    List<Map<String, String>> history = const [],
    String owner = Persona.defaultOwner,
    MemoryStore? memory,
  }) async {
    if (!configured) {
      return const CloudReply.failure(
        'Cloud AI has no API key. Add one in Settings.',
      );
    }
    final result = await _chat([
      {
        'role': 'system',
        'content': IntentContract.systemPrompt(
          device: device,
          routines: routines,
          owner: owner,
          memory: memory ?? MemoryStore(),
        ),
      },
      ...history,
      {'role': 'user', 'content': text},
    ]);
    if (result.error != null) return CloudReply.failure(result.error);

    return IntentContract.parse(
      result.text ?? '',
      device: device,
      routines: routines,
      rawText: text,
    );
  }

  /// Returns null when the provider accepted the request, otherwise a message.
  Future<String?> testConnection() async {
    if (!configured) return 'Add an API key first.';
    final result = await _chat([
      {
        'role': 'user',
        'content': 'Reply with exactly one word: ready',
      },
    ], temperature: 0);
    return result.error;
  }

  Future<({String? text, String? error})> _chat(
    List<Map<String, String>> messages, {
    double temperature = 0.2,
  }) async {
    final payload = jsonEncode({
      'model': model.trim(),
      'messages': messages,
      'temperature': temperature,
      'max_tokens': 300,
    });
    http.Response response;
    for (var attempt = 0;; attempt++) {
      try {
        response = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${apiKey.trim()}',
              },
              body: payload,
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        return (
          text: null,
          error: 'The cloud took too long to answer. Check your connection.',
        );
      } on http.ClientException {
        return (
          text: null,
          error: 'Could not reach the cloud. Check your internet connection.',
        );
      } catch (_) {
        return (
          text: null,
          error: 'Could not reach the cloud. Check your internet connection.',
        );
      }
      if (response.statusCode == 503 && attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        continue;
      }
      break;
    }

    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      final detail = _errorDetail(response.body);
      final keyIssue = response.statusCode == 401 ||
          response.statusCode == 403 ||
          (detail?.toLowerCase().contains('api key') ?? false);
      if (keyIssue) {
        return (
          text: null,
          error: detail == null
              ? 'The API key was rejected. Check it in Settings.'
              : 'The API key was rejected: $detail',
        );
      }
      return (
        text: null,
        error: detail ?? 'The provider rejected the request (HTTP 400).',
      );
    }
    if (response.statusCode == 404) {
      return (
        text: null,
        error: 'That model or endpoint was not found. Check the model name.',
      );
    }
    if (response.statusCode == 429) {
      final detail = _errorDetail(response.body)?.toLowerCase() ?? '';
      // A daily free-tier ceiling (Gemini's "per day ... Free Tier",
      // "retry in 21h") resets on its own — telling people to add billing
      // would be wrong advice for it. _errorDetail truncates to 140 chars
      // and those markers sit at the end of Google's message, so match the
      // raw body here.
      final raw = response.body.toLowerCase();
      final dailyLimit = raw.contains('per day') ||
          raw.contains('per_day') ||
          raw.contains('day limit') ||
          raw.contains('free tier') ||
          RegExp(r'retry in \d+\s*h').hasMatch(raw);
      if (dailyLimit) {
        return (
          text: null,
          error: 'This key has used up today\'s free requests. The limit '
              'resets daily, so try again later or add billing.',
        );
      }
      final noCredit = detail.contains('credit') ||
          detail.contains('quota') ||
          detail.contains('billing');
      if (noCredit) {
        return (
          text: null,
          error:
              'This account has no credits left. Add billing with the provider, then try again.',
        );
      }
      return (
        text: null,
        error: 'The AI provider is rate-limiting requests. Try again shortly.',
      );
    }
    if (response.statusCode == 402) {
      return (
        text: null,
        error:
            'The provider says this account has no credits left. Top up the account or use a free model.',
      );
    }
    if (response.statusCode == 503) {
      return (
        text: null,
        error: 'The model is busy right now. Try again in a moment.',
      );
    }
    if (response.statusCode != 200) {
      return (
        text: null,
        error: 'The AI provider returned an error (HTTP ${response.statusCode}).',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final choices = decoded is Map ? decoded['choices'] : null;
      final first = choices is List && choices.isNotEmpty ? choices.first : null;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        return (text: content, error: null);
      }
      if (content is List) {
        final joined = content
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join()
            .trim();
        if (joined.isNotEmpty) return (text: joined, error: null);
      }
    } catch (_) {}
    return (
      text: null,
      error: 'Cloud AI sent an empty answer. Try another model.',
    );
  }

  String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            final clean =
                message.replaceAll(RegExp(r'\s+'), ' ').trim();
            return clean.length > 140 ? clean.substring(0, 140) : clean;
          }
        }
        if (error is String && error.trim().isNotEmpty) {
          return error.replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
    } catch (_) {}
    return null;
  }
}
