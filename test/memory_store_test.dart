import 'package:emo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<MemoryStore> loaded() async {
    final store = MemoryStore();
    await store.load(await SharedPreferences.getInstance());
    return store;
  }

  test('keeps facts across reloads', () async {
    final store = await loaded();
    expect(await store.add('Likes tea'), isTrue);

    final reloaded = await loaded();
    expect(reloaded.count, 1);
    expect(reloaded.facts.single.text, 'Likes tea');
  });

  test('ignores duplicate facts and strips filler words', () async {
    final store = await loaded();
    await store.add('that I like tea.');
    expect(await store.add('I like tea'), isFalse);
    expect(store.count, 1);
    expect(store.facts.single.text, 'I like tea');
  });

  test('forgets matching facts and clears everything', () async {
    final store = await loaded();
    await store.add('Likes tea');
    await store.add('Works in Dar es Salaam');

    expect(await store.forget('tea'), 1);
    expect(store.count, 1);

    await store.clear();
    expect(store.isEmpty, isTrue);
    final reloaded = await loaded();
    expect(reloaded.isEmpty, isTrue);
  });

  test('caps stored facts and drops the oldest', () async {
    final store = await loaded();
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < MemoryStore.maxFacts + 5; i++) {
      await store.add('fact $i', now: start.add(Duration(minutes: i)));
    }
    expect(store.count, MemoryStore.maxFacts);
    expect(store.facts.first.text, 'fact 5');
    expect(store.facts.last.text, 'fact ${MemoryStore.maxFacts + 4}');
  });
}
