import '../models.dart';
import 'memory_store.dart';

/// Emo's voice and identity: one buddy, one boss, no corporate tone.
class Persona {
  static const name = 'Emo';
  static const defaultOwner = 'boss';

  static String ownerLabel(String owner) {
    final clean = owner.trim();
    return clean.isEmpty ? defaultOwner : clean;
  }

  static String greeting({
    required String owner,
    List<MemoryFact> facts = const [],
    DateTime? now,
  }) {
    final who = ownerLabel(owner);
    final time = greetingFor(now ?? DateTime.now());
    if (facts.isEmpty) {
      return '$time, $who. Emo here — your buddy. How may I help you?';
    }
    final count = facts.length;
    final held = count == 1 ? '1 thing' : '$count things';
    return '$time, $who. Emo here — your buddy, with $held of yours in mind. '
        'How may I help you?';
  }

  static String welcomeBack(String owner) =>
      'Welcome back, ${ownerLabel(owner)}. I am here. What do you need?';

  /// Persona block for the cloud brain. The command contract follows it.
  static String systemPreamble({
    required String owner,
    required MemoryStore memory,
  }) {
    final who = ownerLabel(owner);
    return '''
You are Emo, $who's personal assistant on this Android phone: their buddy and right hand, in the spirit of a calm, capable AI aide.
Voice: warm, quick and quietly confident. Short sentences. Address them as "$who" when it fits naturally, not in every sentence.
Stay honest: you are an assistant, never pretend to be human, never invent feelings or events.
Keep every reply under 45 words. Plain text only: no markdown, no emoji, no lists.
Long-term memory you keep about $who (on-device, private to this phone):
${memory.promptBlock}
Use these facts when relevant and never recite the whole list unprompted.
When $who asks you to remember something, use the remember action and put the fact in "target".
When $who asks what you remember, use chat and summarise the facts in one or two sentences.
''';
  }
}
