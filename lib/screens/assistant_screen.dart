import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import 'home_screen.dart' show VoiceBars;

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.state,
    this.initialCommand,
    this.autoStartVoice = false,
  });

  final AppState state;
  final String? initialCommand;
  final bool autoStartVoice;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool _listening = false;
  String _partial = '';
  int _lastMessages = 0;
  int _lastSteps = 0;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    _lastMessages = state.messages.length;
    _lastSteps = _stepCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialCommand != null &&
          widget.initialCommand!.trim().isNotEmpty) {
        final command = widget.initialCommand!;
        state.submitCommand(command);
      } else if (widget.autoStartVoice) {
        _toggleVoice();
      }
      _scrollToEnd(animate: false);
    });
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _stepCount() =>
      state.messages.fold<int>(0, (sum, message) => sum + message.steps.length);

  void _onStateChanged() {
    final messages = state.messages.length;
    final steps = _stepCount();
    if (messages != _lastMessages) {
      _lastMessages = messages;
      _lastSteps = steps;
      _scrollToEnd();
    } else if (steps != _lastSteps) {
      _lastSteps = steps;
      _scrollToEnd(animate: false);
    }
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent + 60;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _toggleVoice() async {
    final voice = state.voice;
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    voice.onListeningChanged = () {
      if (mounted) setState(() => _listening = voice.listening);
    };
    voice.onPartial = (text) {
      if (mounted) setState(() => _partial = text);
    };
    voice.onError = (message) {
      if (!mounted) return;
      setState(() => _listening = false);
      emoSnack(
        context,
        message,
        icon: Icons.mic_off_rounded,
        color: EmoColors.warning,
      );
    };
    voice.onFinal = (text) async {
      await voice.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _partial = '';
      });
      final command = text.trim();
      if (command.isEmpty) return;
      await state.submitCommand(command);
    };
    final started = await voice.start();
    if (!mounted) return;
    setState(() => _listening = started);
  }

  void _send([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty || state.busy) return;
    _controller.clear();
    _focus.unfocus();
    state.submitCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              final suggestions = CommandSuggestions.list(state.device);
              return Column(
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildMessages(context)),
                  if (_listening) _buildListening(context),
                  _buildSuggestions(context, suggestions),
                  _buildInput(context),
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final device = state.device;
    final status = state.busy
        ? 'Working'
        : (_listening ? 'Listening' : 'Ready');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            size: 42,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Emo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: EmoColors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.busy
                            ? EmoColors.blue
                            : (device.available
                                ? EmoColors.success
                                : EmoColors.warning),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$status · ${device.deviceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: state.voiceReplies
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            size: 40,
            onTap: () => state.setVoiceReplies(!state.voiceReplies),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final messages = state.messages;
    return ListView.builder(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageView(
          message: message,
          onGrant: (need) => showPermissionSheet(context, state, need),
        );
      },
    );
  }

  Widget _buildListening(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF7FFFFFF), Color(0xEEEDF6FF)],
        ),
        child: Row(
          children: [
            const VoiceBars(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _partial.isEmpty ? 'Listening… speak now' : _partial,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _partial.isEmpty ? EmoColors.muted : EmoColors.ink,
                ),
              ),
            ),
            Pressable(
              onTap: _toggleVoice,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: EmoGradients.primary,
                ),
                child: const Icon(Icons.stop_rounded,
                    size: 17, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, List<String> suggestions) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Pressable(
            onTap: state.busy ? null : () => _send(text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: EmoGradients.glassDeep,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded,
                      size: 14, color: EmoColors.blue),
                  const SizedBox(width: 5),
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: EmoColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: GlassSurface(
        radius: 28,
        padding: const EdgeInsets.only(left: 7, right: 7, top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Pressable(
              onTap: _toggleVoice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      _listening ? EmoGradients.primary : EmoGradients.glassDeep,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                  color: _listening ? Colors.white : EmoColors.blueInk,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EmoColors.ink,
                  ),
                  cursorColor: EmoColors.blue,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    hintText: 'Message Emo…',
                    hintStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: EmoColors.faint.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return Pressable(
                  onTap: hasText ? () => _send() : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          hasText ? EmoGradients.primary : EmoGradients.primarySoft,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: hasText ? Colors.white : EmoColors.blueInk,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, required this.onGrant});

  final ChatMessage message;
  final ValueChanged<String> onGrant;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    if (message.fromUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: EmoGradients.userBubble,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x332E7DFF),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              formatTime(message.time),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: EmoColors.faint.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    final showBubble = message.text.isNotEmpty || message.working;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9FD2FF), EmoColors.blue, Color(0xFF1B4DFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x332E7DFF),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: showBubble
                    ? Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: EmoGradients.glassDeep,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7DFF)
                                  .withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: message.working && message.text.isEmpty
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LoadingDots(size: 4.5),
                                  SizedBox(width: 8),
                                  Text(
                                    'Thinking',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: EmoColors.muted,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                message.text,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: EmoColors.ink,
                                ),
                              ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (message.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 39, top: 9),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                ),
                child: _ExecutionPanel(message: message),
              ),
            ),
          if (message.permissionNeed != null && !message.working)
            Padding(
              padding: const EdgeInsets.only(left: 39, top: 9),
              child: _PermissionCard(
                need: message.permissionNeed!,
                onGrant: onGrant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE8FFFFFF), Color(0xD9EEF6FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: EmoColors.blue),
              const SizedBox(width: 5),
              Text(
                message.working ? 'LIVE ACTIONS' : 'ACTIONS',
                style: emoLabel(size: 9),
              ),
              const Spacer(),
              if (message.working) const LoadingDots(size: 3.5),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < message.steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == message.steps.length - 1 ? 0 : 9,
              ),
              child: _StepRow(step: message.steps[i]),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final ExecStep step;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      ExecStatus.done => EmoColors.success,
      ExecStatus.failed => EmoColors.danger,
      ExecStatus.running => EmoColors.blue,
      ExecStatus.pending => EmoColors.faint,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: switch (step.status) {
            ExecStatus.running => const Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(EmoColors.blue),
                ),
              ),
            ExecStatus.done => Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 12, color: color),
              ),
            ExecStatus.failed => Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 12, color: color),
              ),
            ExecStatus.pending => Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.6),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
          },
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: step.status == ExecStatus.pending
                      ? EmoColors.muted
                      : EmoColors.ink,
                ),
              ),
              if (step.detail != null && step.detail!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    step.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: step.status == ExecStatus.failed
                          ? EmoColors.danger
                          : EmoColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.need, required this.onGrant});

  final String need;
  final ValueChanged<String> onGrant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F8FF), Color(0xFFE4F0FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: EmoColors.blueInk),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'One tap to grant access',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: EmoColors.inkSoft,
              ),
            ),
          ),
          Pressable(
            onTap: () => onGrant(need),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: EmoGradients.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Grant',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommandSuggestions {
  static List<String> list(DeviceState device) {
    return [
      if (!device.torchOn) 'Turn on the torch' else 'Turn off the torch',
      'Open WhatsApp',
      'Set brightness to 60%',
      if (!device.dndOn) 'Do not disturb on' else 'Do not disturb off',
      'Read my notifications',
      'Open Camera',
    ].take(5).toList();
  }
}
