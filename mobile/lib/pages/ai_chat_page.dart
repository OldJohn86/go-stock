import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// 聊天消息模型
class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 对话页面 — SSE 流式聊天
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _isLoading = false;
  String _currentResponse = '';
  String? _sessionId;

  /// 最多保留的对话轮数（避免无限增长）
  static const _maxMessages = 80;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _currentResponse = '';
    });
    _scrollToBottom();

    final client = ApiClient();
    client.getSSE(
      '/agent/chat',
      params: {
        'question': text,
        'sessionId': _sessionId ?? '',
      },
      onMessage: (event, data) {
        if (event == 'message' && mounted) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            setState(() => _currentResponse += content);
            _scrollToBottom();
          } catch (_) {}
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          if (_currentResponse.isNotEmpty) {
            _messages.add(_ChatMessage(role: 'assistant', content: _currentResponse));
          }
          _currentResponse = '';
          _isLoading = false;
          // 限制消息数量
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
          }
        });
        _scrollToBottom();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', content: '请求失败: $error'));
          _isLoading = false;
          _currentResponse = '';
        });
      },
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _currentResponse = '';
      _sessionId = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI 分析'),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空对话',
              onPressed: _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_toy, size: 72, color: theme.disabledColor),
                          const SizedBox(height: 20),
                          Text('AI 股票分析', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '输入股票代码或问题，AI 帮你分析行情',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.disabledColor, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildSuggestionChip('今天大盘怎么样？'),
                              _buildSuggestionChip('600519 走势分析'),
                              _buildSuggestionChip('推荐几只股票'),
                              _buildSuggestionChip('当前热点板块'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_currentResponse.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _currentResponse.isNotEmpty) {
                        return _buildMessageBubble(
                          _ChatMessage(role: 'assistant', content: _currentResponse),
                          theme,
                          colorScheme,
                          isStreaming: true,
                        );
                      }
                      return _buildMessageBubble(
                        _messages[index],
                        theme,
                        colorScheme,
                      );
                    },
                  ),
          ),
          // 输入栏
          _buildInputBar(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 13)),
      onPressed: _isLoading
          ? null
          : () {
              _textController.text = text;
              _sendMessage();
            },
    );
  }

  Widget _buildInputBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '输入问题...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                isDense: true,
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: _isLoading ? null : (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 44,
            width: 44,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Material(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _sendMessage,
                      child: const Center(
                        child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    _ChatMessage msg,
    ThemeData theme,
    ColorScheme colorScheme, {
    bool isStreaming = false,
  }) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.smart_toy, size: 16, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isStreaming
                      ? _buildStreamingText(msg, colorScheme)
                      : Text(
                          msg.content,
                          style: TextStyle(
                            color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person, size: 16, color: colorScheme.onPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingText(_ChatMessage msg, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          msg.content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        // Typing indicator animation
        _TypingIndicator(),
      ],
    );
  }
}

/// Animated typing indicator (three bouncing dots)
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.15;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final wave = (math.sin(t * 2 * math.pi) + 1) / 2;
            final size = 5.0 + wave * 3.0;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
