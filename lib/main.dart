import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io_client;

import 'services/api_service.dart';
import 'auth/auth_gate.dart';

void main() => runApp(const WaveChatApp());

const waveGreen = Color(0xFF087F6A);
const waveBackground = Color(0xFFF7F9F8);

class WaveChatApp extends StatelessWidget {
  const WaveChatApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'WaveChat',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: waveBackground,
      colorScheme: ColorScheme.fromSeed(seedColor: waveGreen),
      appBarTheme: const AppBarTheme(
        backgroundColor: waveBackground,
        foregroundColor: Color(0xFF172B27),
        elevation: 0,
      ),
    ),
    home: const AuthGate(),
  );
}

class Chat {
  Chat({
    required this.name,
    required this.message,
    required this.time,
    required this.color,
    String? conversationId,
    this.unread = 0,
    this.online = false,
    this.verified = false,
  }) : conversationId =
           conversationId ??
           name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  final String conversationId;
  final String name;
  String message;
  String time;
  final Color color;
  int unread;
  final bool online;
  final bool verified;
}

class WaveHomePage extends StatefulWidget {
  const WaveHomePage({super.key, this.onLogout});
  final Future<void> Function()? onLogout;
  @override
  State<WaveHomePage> createState() => _WaveHomePageState();
}

class _WaveHomePageState extends State<WaveHomePage> {
  int selectedTab = 0;
  String search = '';
  final ApiService api = ApiService();

  final List<Chat> chats = [];

  bool loadingChats = true;
  String? chatsError;

  @override
  void initState() {
    super.initState();
    loadConversations();
  }

  Future<void> loadConversations() async {
    if (!mounted) return;

    setState(() {
      loadingChats = true;
      chatsError = null;
    });

    try {
      final results = await api.fetchConversations();
      final currentUserId = await api.getCurrentUserId();
      final loadedChats = <Chat>[];

      for (final item in results) {
        final conversationId = item['conversationId']?.toString();
        final otherUser = item['otherUser'];
        final lastMessage = item['lastMessage'];

        if (conversationId == null ||
            conversationId.isEmpty ||
            otherUser is! Map) {
          continue;
        }

        final name = otherUser['name']?.toString() ?? 'Unknown user';
        var message = 'Start a conversation';
        var time = '';

        if (lastMessage is Map) {
          final messageText = lastMessage['text']?.toString() ?? '';
          final senderId = lastMessage['senderId']?.toString();

          message = senderId == currentUserId
              ? 'You: $messageText'
              : messageText;

          final createdAt = DateTime.tryParse(
            lastMessage['createdAt']?.toString() ?? '',
          );

          if (createdAt != null) {
            final localTime = createdAt.toLocal();
            final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
            final minute = localTime.minute.toString().padLeft(2, '0');
            final period = localTime.hour >= 12 ? 'PM' : 'AM';
            time = '$hour:$minute $period';
          }
        }

        loadedChats.add(
          Chat(
            conversationId: conversationId,
            name: name,
            message: message,
            time: time,
            color: const Color(0xFF478F82),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        chats
          ..clear()
          ..addAll(loadedChats);
        loadingChats = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        chatsError = e.toString().replaceFirst('Exception: ', '');
        loadingChats = false;
      });
    }
  }

  List<Chat> get filteredChats => chats
      .where((c) => c.name.toLowerCase().contains(search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: waveGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.waves_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WaveChat',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                'Stay close, always.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'New message',
          onPressed: () => showNewChatDialog(context),
          icon: const Icon(Icons.edit_square, size: 23),
        ),
        IconButton(
          tooltip: 'More options',
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'WaveChat',
            applicationVersion: '0.1.0',
            children: const [Text('Your conversations, closer together.')],
          ),
          icon: const Icon(Icons.more_vert),
        ),
        const SizedBox(width: 5),
      ],
    ),
    body: IndexedStack(
      index: selectedTab,
      children: [
        buildChatsPage(),
        buildSimplePage(
          Icons.auto_awesome_rounded,
          'Your updates',
          'Status updates will appear here.',
        ),
        buildSimplePage(
          Icons.call_outlined,
          'Your calls',
          'Your recent calls will appear here.',
        ),
        buildSettingsPage(),
      ],
    ),
    floatingActionButton: selectedTab == 0
        ? FloatingActionButton(
            backgroundColor: waveGreen,
            foregroundColor: Colors.white,
            tooltip: 'Start a chat',
            onPressed: () => showNewChatDialog(context),
            child: const Icon(Icons.chat_rounded),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: selectedTab,
      onDestinationSelected: (i) => setState(() => selectedTab = i),
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFD9F2E9),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble, color: waveGreen),
          label: 'Chats',
        ),
        NavigationDestination(
          icon: Icon(Icons.circle_outlined),
          selectedIcon: Icon(Icons.circle, color: waveGreen),
          label: 'Updates',
        ),
        NavigationDestination(
          icon: Icon(Icons.call_outlined),
          selectedIcon: Icon(Icons.call, color: waveGreen),
          label: 'Calls',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: waveGreen),
          label: 'Settings',
        ),
      ],
    ),
  );

  Widget buildChatsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
        child: TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172B27),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDDF3EB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filteredChats.length}',
                style: const TextStyle(
                  color: waveGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.filter_list_rounded, color: waveGreen),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: loadingChats
            ? const Center(child: CircularProgressIndicator())
            : chatsError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(chatsError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: loadConversations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : filteredChats.isEmpty
            ? const Center(child: Text('No real conversations yet'))
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: filteredChats.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.only(left: 88),
                  child: Divider(height: 1, color: Color(0xFFE9EEEB)),
                ),
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 7,
                    ),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: chat.color,
                          child: Text(
                            chat.name.isEmpty ? '?' : chat.name[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        if (chat.online)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF27C78A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: waveBackground,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          chat.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: chat.unread > 0 ? waveGreen : Colors.black45,
                            fontWeight: chat.unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (chat.unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 21,
                                minHeight: 21,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: waveGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${chat.unread}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    onTap: () async {
                      setState(() => chat.unread = 0);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatPage(chat: chat)),
                      );
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
      ),
    ],
  );

  Widget buildSimplePage(IconData icon, String title, String description) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3EB),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, color: waveGreen, size: 45),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );

  Widget buildSettingsPage() => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFFDDF3EB),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: waveGreen,
              size: 45,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profile, privacy and notification settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          if (widget.onLogout != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async => widget.onLogout!.call(),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ],
      ),
    ),
  );

  void showNewChatDialog(BuildContext context) {
    final emailController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('New conversation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Registered email',
                    hintText: 'Enter their account email',
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(
                            () => errorMessage = 'Enter a valid email address.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        try {
                          final result = await api.createConversation(
                            email: email,
                          );
                          final conversation =
                              result['conversation'] as Map<String, dynamic>;
                          final otherUser =
                              result['otherUser'] as Map<String, dynamic>;
                          final conversationId = conversation['conversationId']
                              ?.toString();
                          final name = otherUser['name']?.toString() ?? email;
                          if (conversationId == null ||
                              conversationId.isEmpty) {
                            throw Exception(
                              'Server did not return a conversation ID.',
                            );
                          }
                          if (!mounted || !dialogContext.mounted) return;
                          setState(() {
                            chats.removeWhere(
                              (c) => c.conversationId == conversationId,
                            );
                            chats.insert(
                              0,
                              Chat(
                                conversationId: conversationId,
                                name: name,
                                message: 'Start a conversation',
                                time: 'Now',
                                color: const Color(0xFF478F82),
                              ),
                            );
                            selectedTab = 0;
                            search = '';
                          });
                          Navigator.pop(dialogContext);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            errorMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                            isLoading = false;
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        );
      },
    ).then((_) => emailController.dispose());
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chat});
  final Chat chat;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller = TextEditingController();
  final ApiService api = ApiService();
  final List<Map<String, dynamic>> messages = [];
  socket_io_client.Socket? realtimeSocket;
  String? currentUserId;
  bool loading = true;
  bool sending = false;
  String? error;
  String? pendingClientMessageId;
  String? pendingMessageText;
  Map<String, dynamic>? replyingToMessage;

  @override
  void initState() {
    super.initState();
    loadMessages();
    connectRealtime();
  }

  @override
  void dispose() {
    final socket = realtimeSocket;
    if (socket != null) {
      socket.off('message:new');
      socket.disconnect();
      socket.dispose();
    }
    controller.dispose();
    super.dispose();
  }

  DateTime _messageTime(Map<String, dynamic> message) {
    final value = message['createdAt'];
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _upsertMessage(Map<String, dynamic> incoming) {
    final incomingId = incoming['id'];
    final incomingClientId = incoming['clientMessageId'];
    final index = messages.indexWhere((existing) {
      final sameId =
          incomingId is String &&
          incomingId.isNotEmpty &&
          existing['id'] == incomingId;
      final sameClientId =
          incomingClientId is String &&
          incomingClientId.isNotEmpty &&
          existing['clientMessageId'] == incomingClientId;
      return sameId || sameClientId;
    });
    if (index == -1) {
      messages.add(Map<String, dynamic>.from(incoming));
    } else {
      messages[index] = {...messages[index], ...incoming};
    }
    messages.sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
  }

  Future<void> connectRealtime() async {
    try {
      final token = await api.getAuthToken();
      final userId = await api.getCurrentUserId();
      if (!mounted || token == null || token.isEmpty) return;
      setState(() => currentUserId = userId);
      final socketUrl = api.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
      final socket = socket_io_client.io(
        socketUrl,
        socket_io_client.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableForceNew()
            .disableAutoConnect()
            .enableReconnection()
            .build(),
      );
      realtimeSocket = socket;
      socket.onConnect((_) {
        debugPrint('[WaveChat] Socket connected');
        socket.emitWithAck(
          'conversation:join',
          {'conversationId': widget.chat.conversationId},
          ack: (dynamic response) {
            if (response is Map && response['ok'] == true) {
              debugPrint('[WaveChat] Conversation room joined');
              loadMessages(showLoading: false);
            } else {
              debugPrint('[WaveChat] Conversation room join rejected');
            }
          },
        );
      });
      socket.onConnectError(
        (dynamic e) => debugPrint('[WaveChat] Socket connection error: $e'),
      );
      socket.on('message:new', (dynamic payload) {
        if (payload is! Map) return;
        final incoming = Map<String, dynamic>.from(payload);
        if (incoming['conversationId'] != widget.chat.conversationId ||
            !mounted) {
          return;
        }
        setState(() {
          _upsertMessage(incoming);
          final incomingText = incoming['text'];
          if (incomingText is String) widget.chat.message = incomingText;
          widget.chat.time = 'Now';
        });
      });
      socket.connect();
    } catch (e) {
      debugPrint('[WaveChat] Realtime setup failed: $e');
    }
  }

  Future<void> loadMessages({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await api.fetchMessages(
        conversationId: widget.chat.conversationId,
      );
      if (!mounted) return;
      setState(() {
        for (final message in result) {
          _upsertMessage(message);
        }
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[WaveChat] Message fetch failed: $e');
      setState(() {
        loading = false;
        error = 'Server se connect nahi ho paya.';
      });
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    final String clientMessageId;
    if (pendingClientMessageId != null && pendingMessageText == text) {
      clientMessageId = pendingClientMessageId!;
    } else {
      clientMessageId = '${DateTime.now().microsecondsSinceEpoch}-wavechat';
      pendingClientMessageId = clientMessageId;
      pendingMessageText = text;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final message = await api.sendMessage(
        conversationId: widget.chat.conversationId,
        clientMessageId: clientMessageId,
        text: text,
        senderId: currentUserId ?? '',
        replyToMessageId: replyingToMessage?['id'] as String?,
      );
      if (!mounted) return;
      setState(() {
        _upsertMessage(message);
        widget.chat.message = text;
        widget.chat.time = 'Now';
        controller.clear();
        replyingToMessage = null;
        pendingClientMessageId = null;
        pendingMessageText = null;
        sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[WaveChat] Message send failed: $e');
      setState(() {
        sending = false;
        error =
            'Message nahi bheja gaya. Connection check karo aur retry karo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.chat.name),
      actions: [
        IconButton(
          onPressed: loadMessages,
          tooltip: 'Refresh messages',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(
                onPressed: pendingClientMessageId != null
                    ? sendMessage
                    : loadMessages,
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? const Center(child: Text('Say hello!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final text = message['text'] as String? ?? '';
                    final sender = message['senderId'] as String? ?? '';
                    final isMine =
                        currentUserId != null && sender == currentUserId;
                    final reply = message['replyTo'];
                    final replyText = reply is Map
                        ? reply['text']?.toString()
                        : null;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (sheetContext) => SafeArea(
                            child: ListTile(
                              leading: const Icon(Icons.reply),
                              title: const Text('Reply'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                setState(
                                  () => replyingToMessage =
                                      Map<String, dynamic>.from(message),
                                );
                              },
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFFD9F2E9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (replyText != null && replyText.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    border: const Border(
                                      left: BorderSide(
                                        color: waveGreen,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    replyText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              Text(text),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyingToMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: waveGreen),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, color: waveGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Replying to message',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: waveGreen,
                              ),
                            ),
                            Text(
                              replyingToMessage?['text'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        onPressed: () =>
                            setState(() => replyingToMessage = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !sending,
                        onSubmitted: (_) => sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: sending ? null : sendMessage,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
