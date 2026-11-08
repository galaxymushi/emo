import 'dart:io';

import 'package:emo/models.dart';
import 'package:emo/services/command_engine.dart';
import 'package:emo/services/device_bridge.dart';
import 'package:emo/services/local_brain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _tiny = LocalModel(
  id: 'tiny',
  name: 'Tiny test model',
  fileName: 'tiny.task',
  url: 'https://example.com/tiny.task',
  bytes: 1024,
  description: 'Test model',
);

class FakeRuntime implements LocalRuntime {
  FakeRuntime(this.directory, {this.text = 'Hello, boss.'});

  final String directory;
  String text;
  int loads = 0;
  int generates = 0;
  int installs = 0;
  bool unloaded = false;
  bool bundled = false;
  String? installError;
  String? lastPrompt;

  @override
  Future<String> modelDirectory() async => directory;

  @override
  Future<bool> isBundled(String fileName) async => bundled;

  @override
  Future<LocalLlmResult> install(String fileName, int bytes) async {
    installs++;
    final failure = installError;
    if (failure != null) {
      return LocalLlmResult(ok: false, message: failure);
    }
    await File('${directory.isEmpty ? '' : '$directory/'}$fileName')
        .writeAsBytes(List.filled(bytes, 1));
    return const LocalLlmResult(ok: true, message: 'installed');
  }

  @override
  Future<LocalLlmResult> load(String path, {int maxTokens = 1024}) async {
    loads++;
    return const LocalLlmResult(ok: true, message: 'loaded');
  }

  @override
  Future<LocalLlmResult> generate(String prompt) async {
    generates++;
    lastPrompt = prompt;
    return LocalLlmResult(ok: true, text: text);
  }

  @override
  Future<void> unload() async {
    unloaded = true;
  }
}

Future<Directory> _tempDir() => Directory.systemTemp.createTemp('emo_local_');

void main() {
  group('LocalBrain install state', () {
    test('reports a model only when the file is complete', () async {
      final dir = await _tempDir();
      final runtime = FakeRuntime(dir.path);
      final brain = LocalBrain(runtime: runtime)..model = _tiny;

      await brain.init();
      expect(brain.installed, isFalse);

      await File('${dir.path}/tiny.task').writeAsBytes(List.filled(1024, 1));
      await brain.refresh();
      expect(brain.installed, isTrue);

      await File('${dir.path}/tiny.task').writeAsBytes([1, 2]);
      await brain.refresh();
      expect(brain.installed, isFalse);
    });

    test('downloads with progress and marks the model installed', () async {
      final dir = await _tempDir();
      final brain = LocalBrain(
        runtime: FakeRuntime(dir.path),
        client: MockClient((_) async => http.Response.bytes(
              List.filled(1024, 7),
              200,
            )),
      )..model = _tiny;

      final reports = <double>[];
      final error = await brain.download(onProgress: reports.add);

      expect(error, isNull);
      expect(brain.installed, isTrue);
      expect(reports.first, 0);
      expect(reports.last, 1);
      expect(File('${dir.path}/tiny.task').lengthSync(), 1024);
    });

    test('reports a failed download honestly', () async {
      final dir = await _tempDir();
      final brain = LocalBrain(
        runtime: FakeRuntime(dir.path),
        client: MockClient((_) async => http.Response('nope', 404)),
      )..model = _tiny;

      final error = await brain.download();

      expect(error, contains('404'));
      expect(brain.installed, isFalse);
    });

    test('unpacks a bundled model instead of downloading it', () async {
      final dir = await _tempDir();
      final runtime = FakeRuntime(dir.path)..bundled = true;
      final brain = LocalBrain(runtime: runtime)..model = _tiny;

      await brain.init();
      expect(brain.bundled, isTrue);
      expect(brain.installed, isFalse);

      final error = await brain.ensureInstalled();

      expect(error, isNull);
      expect(brain.installed, isTrue);
      expect(runtime.installs, 1);
      expect(File('${dir.path}/tiny.task').lengthSync(), 1024);

      // A second call is a no-op: the model is already on disk.
      await brain.ensureInstalled();
      expect(runtime.installs, 1);
    });

    test('a build without a bundled model never tries to install', () async {
      final dir = await _tempDir();
      final runtime = FakeRuntime(dir.path);
      final brain = LocalBrain(runtime: runtime)..model = _tiny;

      await brain.init();
      expect(brain.bundled, isFalse);

      final error = await brain.ensureInstalled();

      expect(error, isNull);
      expect(brain.installed, isFalse);
      expect(runtime.installs, 0);
    });

    test('a failed bundled install is reported honestly', () async {
      final dir = await _tempDir();
      final runtime = FakeRuntime(dir.path)
        ..bundled = true
        ..installError = 'The bundled model came through incomplete.';
      final brain = LocalBrain(runtime: runtime)..model = _tiny;
      await brain.init();

      final error = await brain.ensureInstalled();

      expect(error, contains('incomplete'));
      expect(brain.installed, isFalse);
    });
  });

  group('LocalBrain answers', () {
    test('turns JSON into a real device intent', () async {
      final dir = await _tempDir();
      await File('${dir.path}/tiny.task').writeAsBytes(List.filled(1024, 1));
      final runtime = FakeRuntime(dir.path, text: '{"action":"torch","on":true}');
      final brain = LocalBrain(runtime: runtime)..model = _tiny;
      await brain.init();

      final reply = await brain.interpret(
        text: 'light it up for me',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, isNull);
      expect(reply.command?.kind, IntentKind.torch);
      expect(reply.command?.on, isTrue);
      expect(runtime.lastPrompt, contains('light it up for me'));
      expect(runtime.lastPrompt, contains('one JSON object'));
    });

    test('plain text becomes a chat answer without template tokens', () async {
      final dir = await _tempDir();
      await File('${dir.path}/tiny.task').writeAsBytes(List.filled(1024, 1));
      final brain = LocalBrain(
        runtime: FakeRuntime(
          dir.path,
          text: '<|im_start|>assistant\nI am here, boss.<|im_end|>',
        ),
      )..model = _tiny;
      await brain.init();

      final reply = await brain.interpret(
        text: 'you there?',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.command, isNull);
      expect(reply.chat, 'I am here, boss.');
    });

    test('loads the model once and reuses it', () async {
      final dir = await _tempDir();
      await File('${dir.path}/tiny.task').writeAsBytes(List.filled(1024, 1));
      final runtime = FakeRuntime(dir.path);
      final brain = LocalBrain(runtime: runtime)..model = _tiny;
      await brain.init();

      await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );
      await brain.interpret(
        text: 'and again',
        device: const DeviceState(),
        routines: const [],
      );

      expect(runtime.loads, 1);
      expect(runtime.generates, 2);
    });

    test('unpacks a bundled model on first use', () async {
      final dir = await _tempDir();
      final runtime = FakeRuntime(
        dir.path,
        text: '{"action":"torch","on":true}',
      )..bundled = true;
      final brain = LocalBrain(runtime: runtime)..model = _tiny;
      await brain.init();
      expect(brain.installed, isFalse);

      final reply = await brain.interpret(
        text: 'light it up for me',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.command?.kind, IntentKind.torch);
      expect(runtime.installs, 1);
      expect(brain.installed, isTrue);
    });

    test('explains a missing download instead of guessing', () async {
      final dir = await _tempDir();
      final brain = LocalBrain(runtime: FakeRuntime(dir.path))..model = _tiny;
      await brain.init();

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.command, isNull);
      expect(reply.chat, isNull);
      expect(reply.error, contains('not downloaded'));
    });
  });

  group('prompt building', () {
    test('includes the persona, recent history and the JSON reminder', () {
      final prompt = buildPrompt(
        system: 'You are Emo.',
        text: 'make it darker',
        history: const [
          {'role': 'user', 'content': 'earlier'},
          {'role': 'assistant', 'content': 'noted'},
        ],
      );

      expect(prompt, startsWith('You are Emo.'));
      expect(prompt, contains('Boss: earlier'));
      expect(prompt, contains('Emo: noted'));
      expect(prompt, contains('Boss: make it darker'));
      expect(prompt, contains('one JSON object only'));
    });

    test('strips fences and template tokens', () {
      expect(
        cleanOutput('```json\n{"action":"chat","reply":"Hi."}\n```'),
        '{"action":"chat","reply":"Hi."}',
      );
      expect(cleanOutput('<|im_start|>Emo: Hi.<|im_end|>'), 'Hi.');
    });
  });
}
