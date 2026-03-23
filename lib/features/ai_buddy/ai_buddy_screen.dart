import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/pulsing_mic_button.dart';

class AiBuddyScreen extends ConsumerStatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  ConsumerState<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends ConsumerState<AiBuddyScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _stt = SpeechToText();
  bool _sttAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _sttAvailable = await _stt.initialize();
    if (mounted) setState(() {});
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _toggleListening() async {
    final notifier = ref.read(chatProvider.notifier);
    if (_stt.isListening) {
      await _stt.stop();
      notifier.setListening(false);
    } else {
      if (!_sttAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available')),
          );
        }
        return;
      }
      notifier.setListening(true);
      await _stt.listen(
        onResult: (result) {
          _textCtrl.text = result.recognizedWords;
          if (result.finalResult) notifier.setListening(false);
        },
      );
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    // ── Auto-scroll whenever message count changes ────────────────────────
    ref.listen<ChatState>(chatProvider, (prev, next) {
      final prevCount = (prev?.messages.length ?? 0) + (prev?.isAiThinking == true ? 1 : 0);
      final nextCount = next.messages.length + (next.isAiThinking ? 1 : 0);
      if (nextCount != prevCount) _scrollToBottom();
    });

    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Echelon AI', style: AppTextStyles.titleLg),
                Text('Finance Buddy', style: AppTextStyles.labelSm),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref.read(chatProvider.notifier).clearHistory(),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat list ───────────────────────────────────────────────────
          Expanded(
            child: chatState.messages.isEmpty
                ? _WelcomePrompt(
                    onExampleTap: (text) {
                      _textCtrl.text = text;
                      _send();
                    },
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: chatState.messages.length +
                        (chatState.isAiThinking ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= chatState.messages.length) {
                        return const _ThinkingIndicator();
                      }
                      final msg = chatState.messages[i];
                      // Animated entrance per bubble
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(msg.id),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (ctx, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: ChatBubble(message: msg, currency: currency),
                      );
                    },
                  ),
          ),

          // ── Input bar ───────────────────────────────────────────────────
          Container(
            color: AppColors.surfaceContainerLowest,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    onSubmitted: (_) => _send(),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Type a transaction or question...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                PulsingMicButton(
                  isListening: chatState.isListening,
                  onTap: _toggleListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Welcome screen ────────────────────────────────────────────────────────────

class _WelcomePrompt extends StatelessWidget {
  final ValueChanged<String> onExampleTap;
  const _WelcomePrompt({required this.onExampleTap});

  static const examples = [
    'Spent ₹450 on lunch today',
    'Got salary of ₹75,000 this month',
    'Paid ₹1,200 for Netflix subscription',
    'How am I doing on my budget?',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    size: 36, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hi! I\'m Echelon', style: AppTextStyles.headlineLg),
            const SizedBox(height: 8),
            Text(
              'Tell me about a transaction and I\'ll log it for you.\nWorks even without an API key!',
              style: AppTextStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text('Try saying:', style: AppTextStyles.labelLg),
            const SizedBox(height: 12),
            ...List.generate(examples.length, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + i * 60),
                curve: Curves.easeOut,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                      offset: Offset(0, 12 * (1 - v)), child: child),
                ),
                child: GestureDetector(
                  onTap: () => onExampleTap(examples[i]),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Text(examples[i], style: AppTextStyles.bodyMd),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Thinking indicator (animated dots) ───────────────────────────────────────

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
