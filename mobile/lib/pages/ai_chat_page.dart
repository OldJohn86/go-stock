import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../api/api_client.dart';

/// AI 模型配置
class _AiModelConfig {
  final int id;
  final String name;
  final String baseUrl;
  final bool hasApiKey;
  final bool isOllama;

  _AiModelConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.hasApiKey,
    required this.isOllama,
  });

  bool get isSecure => isOllama || hasApiKey;

  String get displayName {
    if (isOllama) return name;
    return hasApiKey ? name : '$name 🔒';
  }
}

/// 聊天消息模型
class _ChatMessage {
  final String role;
  final String content;
  final String? reasoningContent;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.content,
    this.reasoningContent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 对话页面 — SSE 流式聊天 + 模型选择
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
  String _currentReasoning = '';
  String? _sessionId;

  // AI 模型选择
  List<_AiModelConfig> _aiModels = [];
  int _selectedAiConfigId = 1;
  
  // 高级选项
  bool _thinkingMode = false;
  String _agentMode = 'react'; // 'react' or 'simple'

  static const _maxMessages = 80;

  @override
  void initState() {
    super.initState();
    _loadAiModels();
  }

  Future<void> _loadAiModels() async {
    try {
      final resp = await ApiClient().get('/settings/ai-configs');
      if (resp.isSuccess && resp.data != null) {
        setState(() {
          _aiModels = (resp.data as List).map((item) {
            final map = item as Map<String, dynamic>;
            final baseUrl = map['baseUrl']?.toString() ?? '';
            final isOllama = baseUrl.contains(':11434') ||
                baseUrl.toLowerCase().contains('ollama');
            return _AiModelConfig(
              id: map['id'] as int? ?? 0,
              name: map['name']?.toString() ?? '未命名',
              baseUrl: baseUrl,
              hasApiKey: map['hasApiKey'] == true,
              isOllama: isOllama,
            );
          }).toList();
          if (_aiModels.isNotEmpty) {
            final current = _aiModels.firstWhere(
              (m) => m.id == _selectedAiConfigId,
              orElse: () => _aiModels.first,
            );
            _selectedAiConfigId = current.id;
            _thinkingMode = current.isOllama;
          }
        });
      }
    } catch (e) {
      debugPrint('Load AI models failed: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    if (_selectedModel != null && !_selectedModel!.isSecure) {
      _showModelErrorDialog();
      return;
    }

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _currentResponse = '';
      _currentReasoning = '';
    });
    _scrollToBottom();

    final client = ApiClient();
    client.getSSE(
      '/agent/chat',
      params: {
        'question': text,
        'aiConfigId': _selectedAiConfigId,
        'thinkingMode': _thinkingMode.toString(),
        'agentMode': _agentMode,
        'memoryMode': 'true',
        'memoryCount': '10',
        'sessionId': _sessionId ?? '',
      },
      onMessage: (event, data) {
        if (event == 'message' && mounted) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            final reasoning = json['reasoningContent'] as String? ?? '';
            setState(() {
              if (reasoning.isNotEmpty) {
                _currentReasoning += reasoning;
              } else {
                _currentResponse += content;
              }
            });
            _scrollToBottom();
          } catch (_) {}
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          if (_currentResponse.isNotEmpty || _currentReasoning.isNotEmpty) {
            _messages.add(_ChatMessage(
              role: 'assistant',
              content: _currentResponse,
              reasoningContent: _currentReasoning.isEmpty
                  ? null
                  : _currentReasoning,
            ));
          }
          _currentResponse = '';
          _currentReasoning = '';
          _isLoading = false;
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
          }
        });
        _scrollToBottom();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _messages.add(_ChatMessage(
              role: 'assistant', content: '请求失败: $error'));
          _isLoading = false;
          _currentResponse = '';
          _currentReasoning = '';
        });
      },
    );
  }

  _AiModelConfig? get _selectedModel {
    if (_aiModels.isEmpty) return null;
    return _aiModels.firstWhere(
      (m) => m.id == _selectedAiConfigId,
      orElse: () => _aiModels.first,
    );
  }

  void _showModelErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 模型未配置'),
        content: const Text(
          '当前选中的 AI 模型缺少 API Key。\n\n'
          '请在设置页测试并配置 AI 模型服务，或在桌面端添加配置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _currentResponse = '';
      _currentReasoning = '';
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
          // AI 模型选择器
          if (_aiModels.isNotEmpty)
            _buildModelSelector(theme, colorScheme),
          // 高级选项
          _buildOptionsMenu(),
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
          // 当前模型指示条
          if (_selectedModel != null) _buildModelIndicator(colorScheme),
          // 消息列表
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount:
                        _messages.length + (_currentResponse.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length &&
                          _currentResponse.isNotEmpty) {
                        return _buildMessageBubble(
                          _ChatMessage(
                            role: 'assistant',
                            content: _currentResponse,
                            reasoningContent: _currentReasoning.isEmpty
                                ? null
                                : _currentReasoning,
                          ),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
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
              style:
                  TextStyle(color: theme.disabledColor, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
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
    );
  }

  Widget _buildModelSelector(ThemeData theme, ColorScheme cs) {
    return PopupMenuButton<int>(
      icon: Icon(
        Icons.arrow_drop_down_circle,
        color: _selectedModel?.isSecure == false ? Colors.orange : null,
      ),
      tooltip: '切换 AI 模型',
      onSelected: (id) => setState(() => _selectedAiConfigId = id),
      itemBuilder: (ctx) => _aiModels.map((model) {
        final selected = model.id == _selectedAiConfigId;
        return CheckedPopupMenuItem<int>(
          value: model.id,
          checked: selected,
          child: Text(model.displayName),
        );
      }).toList(),
    );
  }

  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune),
      tooltip: '高级选项',
      onSelected: (value) {
        if (value == 'thinking') {
          setState(() => _thinkingMode = !_thinkingMode);
        } else if (value == 'agent') {
          setState(() => _agentMode = _agentMode == 'react' ? 'simple' : 'react');
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'thinking',
          child: Row(
            children: [
              Icon(Icons.psychology, size: 18),
              SizedBox(width: 10),
              Text('Thinking 模式'),
              Spacer(),
              Icon(Icons.check, size: 16),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'agent',
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 10),
              const Text('Agent 模式'),
              const Spacer(),
              Text(_agentMode, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelIndicator(ColorScheme cs) {
    final model = _selectedModel;
    if (model == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            model.isOllama ? Icons.memory : Icons.cloud,
            size: 14,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            model.name,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_thinkingMode) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Thinking',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
        border: Border(
            top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5))),
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
                fillColor: theme.colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
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
                        child: Icon(Icons.send_rounded,
                            size: 20, color: Colors.white),
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
              child: Icon(Icons.smart_toy,
                  size: 16, color: colorScheme.onPrimaryContainer),
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
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
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
                  // Reasoning content (if any)
                  if (!isUser && msg.reasoningContent != null &&
                      msg.reasoningContent!.isNotEmpty) ...[
                    _buildReasoningCard(msg.reasoningContent!, colorScheme),
                    const SizedBox(height: 8),
                  ],
                  if (isStreaming)
                    _buildStreamingText(msg, colorScheme)
                  else if (isUser)
                    Text(
                      msg.content,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.45,
                        ),
                        a: TextStyle(color: colorScheme.primary),
                        code: TextStyle(
                          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        listBullet: TextStyle(color: colorScheme.onSurface),
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
              child: Icon(Icons.person,
                  size: 16, color: colorScheme.onPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasoningCard(
      String reasoning, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.purple.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology,
                  size: 14, color: Colors.purple[700]),
              const SizedBox(width: 6),
              Text(
                '思考过程',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reasoning,
            style: TextStyle(
              fontSize: 13,
              color: Colors.purple[800]?.withValues(alpha: 0.8),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingText(
      _ChatMessage msg, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: msg.content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _TypingIndicator(color: colorScheme.onSurface),
      ],
    );
  }
}

/// Animated typing indicator (three bouncing dots)
class _TypingIndicator extends StatefulWidget {
  final Color? color;

  const _TypingIndicator({this.color});

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
    final dotColor = widget.color ?? Colors.white70;
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
                decoration: BoxDecoration(
                  color: dotColor,
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