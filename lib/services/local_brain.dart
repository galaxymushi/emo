import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'device_bridge.dart';
import 'intent_contract.dart';
import 'memory_store.dart';
import 'persona.dart';

class LocalModel {
  const LocalModel({
    required this.id,
    required this.name,
    required this.fileName,
    required this.url,
    required this.bytes,
    required this.description,
  });

  final String id;
  final String name;
  final String fileName;
  final String url;
  final int bytes;
  final String description;

  String get sizeLabel => '${(bytes / (1024 * 1024)).round()} MB';

  /// Apache-2.0, ungated on Hugging Face, quantized for phone CPUs.
  static const qwen = LocalModel(
    id: 'qwen2.5-0.5b',
    name: 'Qwen 2.5 · 0.5B',
    fileName: 'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    url:
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    bytes: 546660344,
    description: 'Small and fast. Understands paraphrases and answers short '
        'questions without sending anything off the phone.',
  );

  static const all = [qwen];

  static LocalModel byId(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return qwen;
  }
}

abstract class LocalRuntime {
  Future<String> modelDirectory();

  Future<LocalLlmResult> load(String path, {int maxTokens = 1024});

  Future<LocalLlmResult> generate(String prompt);

  Future<void> unload();

  /// Whether this build ships [fileName] inside the APK.
  Future<bool> isBundled(String fileName);

  /// Copies the bundled model out of the APK; reports success and state.
  Future<LocalLlmResult> install(String fileName, int bytes);
}

class NativeLocalRuntime implements LocalRuntime {
  NativeLocalRuntime({DeviceBridge? bridge}) : _bridge = bridge ?? DeviceBridge();

  final DeviceBridge _bridge;

  @override
  Future<String> modelDirectory() async {
    final root = await _bridge.filesDir();
    if (root.isEmpty) return '';
    return '$root/models';
  }

  @override
  Future<LocalLlmResult> load(String path, {int maxTokens = 1024}) =>
      _bridge.localLlmLoad(path, maxTokens: maxTokens);

  @override
  Future<LocalLlmResult> generate(String prompt) => _bridge.localLlmGenerate(prompt);

  @override
  Future<void> unload() => _bridge.localLlmUnload();

  @override
  Future<bool> isBundled(String fileName) => _bridge.localLlmBundled(fileName);

  @override
  Future<LocalLlmResult> install(String fileName, int bytes) =>
      _bridge.localLlmInstall(fileName, bytes);
}

class LocalBrain {
  LocalBrain({LocalRuntime? runtime, http.Client? client})
      : _runtime = runtime ?? NativeLocalRuntime(),
        _client = client ?? http.Client();

  static const maxTokens = 1024;

  final LocalRuntime _runtime;
  final http.Client _client;

  LocalModel model = LocalModel.qwen;
  bool enabled = false;
  bool installed = false;

  /// True when this APK ships with the model inside it.
  bool bundled = false;

  /// True while a bundled model is being copied out of the APK.
  bool installing = false;
  bool downloading = false;
  bool loaded = false;
  double progress = 0;
  String? error;
  String _directory = '';
  bool _cancelled = false;

  String? get modelPath =>
      _directory.isEmpty ? null : '$_directory/${model.fileName}';

  String get storageLabel => model.sizeLabel;

  Future<void> init() async {
    try {
      _directory = await _runtime.modelDirectory();
      await refresh();
    } catch (_) {
      installed = false;
    }
  }

  Future<void> refresh() async {
    try {
      bundled = await _runtime.isBundled(model.fileName);
    } catch (_) {
      bundled = false;
    }
    final path = modelPath;
    if (path == null) {
      installed = false;
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      installed = false;
      return;
    }
    final length = await file.length();
    installed = length >= (model.bytes * 0.98).round();
  }

  /// Materializes the model that ships inside the APK, once. Returns an error
  /// message when the bundled copy could not be installed, otherwise null.
  Future<String?> ensureInstalled() async {
    if (installed || installing) return null;
    if (!bundled) return null;
    installing = true;
    error = null;
    try {
      final result = await _runtime.install(model.fileName, model.bytes);
      await refresh();
      if (!installed) {
        error = result.message.isEmpty
            ? 'The bundled model could not be installed.'
            : result.message;
        return error;
      }
      return null;
    } catch (_) {
      error = 'The bundled model could not be installed.';
      return error;
    } finally {
      installing = false;
    }
  }

  Future<String?> download({void Function(double progress)? onProgress}) async {
    if (downloading) return 'A download is already running.';
    if (_directory.isEmpty) {
      _directory = await _runtime.modelDirectory();
    }
    if (_directory.isEmpty) return 'This phone did not provide a storage folder.';
    final dir = Directory(_directory);
    if (!await dir.exists()) await dir.create(recursive: true);

    final target = File('$_directory/${model.fileName}');
    final partial = File('${target.path}.part');
    downloading = true;
    _cancelled = false;
    progress = 0;
    error = null;
    onProgress?.call(0);
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(model.url));
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        error = 'The model download failed (HTTP ${response.statusCode}).';
        return error;
      }
      final total = response.contentLength ?? model.bytes;
      sink = partial.openWrite();
      var received = 0;
      var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in response.stream) {
        if (_cancelled) {
          error = 'Download cancelled.';
          return error;
        }
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReport) >
            const Duration(milliseconds: 400)) {
          lastReport = now;
          progress = total <= 0 ? 0 : (received / total).clamp(0, 1);
          onProgress?.call(progress);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled) {
        error = 'Download cancelled.';
        return error;
      }
      final length = await partial.length();
      if (length < (model.bytes * 0.98).round()) {
        await partial.delete();
        error = 'The model file came through incomplete. Try again.';
        return error;
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      installed = true;
      progress = 1;
      onProgress?.call(1);
      return null;
    } on TimeoutException {
      error = 'The download timed out. Check your connection and try again.';
      return error;
    } on http.ClientException {
      error = 'Could not reach the model host. Check your connection.';
      return error;
    } on FileSystemException {
      error = 'The model could not be saved on this phone.';
      return error;
    } catch (_) {
      error = 'The model download failed. Try again.';
      return error;
    } finally {
      downloading = false;
      try {
        await sink?.close();
      } catch (_) {}
      if (_cancelled) {
        try {
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
      }
    }
  }

  void cancelDownload() {
    _cancelled = true;
  }

  Future<void> delete() async {
    await unload();
    final path = modelPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      final partial = File('$path.part');
      if (await partial.exists()) await partial.delete();
    } catch (_) {}
    installed = false;
    progress = 0;
  }

  Future<String?> load() async {
    final path = modelPath;
    if (path == null) return 'The model is not downloaded yet.';
    if (!await File(path).exists()) {
      installed = false;
      return 'The model file is missing. Download it again.';
    }
    if (loaded) return null;
    error = null;
    try {
      final result = await _runtime
          .load(path, maxTokens: maxTokens)
          .timeout(const Duration(seconds: 180));
      if (!result.ok) {
        error = result.message.isEmpty ? 'The model failed to load.' : result.message;
        return error;
      }
      loaded = true;
      return null;
    } on TimeoutException {
      error = 'The model took too long to load.';
      return error;
    } catch (_) {
      error = 'The model failed to load.';
      return error;
    }
  }

  Future<void> unload() async {
    try {
      await _runtime.unload();
    } catch (_) {}
    loaded = false;
  }

  Future<CloudReply> interpret({
    required String text,
    required DeviceState device,
    required List<Routine> routines,
    List<Map<String, String>> history = const [],
    String owner = Persona.defaultOwner,
    MemoryStore? memory,
  }) async {
    if (!installed && bundled) {
      // First use of a model that ships inside the APK: copy it out.
      final installError = await ensureInstalled();
      if (installError != null) return CloudReply.failure(installError);
    }
    if (!installed) {
      return const CloudReply.failure(
        'The on-device model is not downloaded yet.',
      );
    }
    final loadError = await load();
    if (loadError != null) return CloudReply.failure(loadError);

    final prompt = buildPrompt(
      system: IntentContract.systemPrompt(
        device: device,
        routines: routines,
        owner: owner,
        memory: memory ?? MemoryStore(),
      ),
      text: text,
      history: history,
    );
    LocalLlmResult result;
    try {
      result = await _runtime
          .generate(prompt)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      return const CloudReply.failure(
        'The on-device model took too long. Try a shorter request.',
      );
    } catch (_) {
      return const CloudReply.failure(
        'The on-device model could not answer. Try again.',
      );
    }
    if (!result.ok) {
      return CloudReply.failure(
        result.message.isEmpty
            ? 'The on-device model could not answer.'
            : result.message,
      );
    }

    final clean = cleanOutput(result.text);
    if (clean.isEmpty) {
      return const CloudReply.failure('The on-device model sent an empty answer.');
    }
    if (!clean.contains('{')) return CloudReply.chat(clean);
    final parsed = IntentContract.parse(
      clean,
      device: device,
      routines: routines,
      rawText: text,
      source: 'The on-device model',
    );
    if (parsed.chat != null && parsed.chat!.isEmpty) {
      return const CloudReply.failure('The on-device model sent an empty answer.');
    }
    return parsed;
  }

  void close() => _client.close();
}

String buildPrompt({
  required String system,
  required String text,
  List<Map<String, String>> history = const [],
}) {
  final buffer = StringBuffer(system.trim());
  for (final turn in history.reversed.take(4).toList().reversed) {
    final role = turn['role'] == 'user' ? 'Boss' : 'Emo';
    final content = (turn['content'] ?? '').trim();
    if (content.isEmpty) continue;
    buffer.write('\n\n$role: $content');
  }
  buffer.write('\n\nBoss: ${text.trim()}');
  buffer.write(
    '\n\nAnswer the last message with one JSON object only.',
  );
  return buffer.toString();
}

/// Strips chat-template artefacts so a small model's output is presentable.
String cleanOutput(String raw) {
  var text = raw
      .replaceAll(RegExp(r'<\|[^>]*\|>'), ' ')
      .replaceAll(RegExp(r'</?(?:s|start_of_turn|end_of_turn|im_start|im_end)>'),
          ' ')
      .replaceAll(RegExp(r'^\s*(?:assistant|emo|ai)\s*[:\-]?\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const stops = ['<|im_end|>', '<end_of_turn>', '<|endoftext|>'];
  for (final stop in stops) {
    final index = text.indexOf(stop);
    if (index != -1) text = text.substring(0, index).trim();
  }
  if (text.startsWith('```')) {
    text = text
        .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
  return text;
}
