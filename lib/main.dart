import 'auth/auth_gate.dart';

import 'package:flutter/material.dart';

import 'services/api_service.dart';

void main() {
  runApp(const WaveChatApp());
}

const Color waveGreen = Color(0xFF087F6A);
const Color waveBackground = Color(0xFFF7F9F8);

class WaveChatApp extends StatelessWidget {
  const WaveChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  const WaveHomePage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<WaveHomePage> createState() => _WaveHomePageState();
}

class _WaveHomePageState extends State<WaveHomePage> {
  int selectedTab = 0;
  String search = '';

  final List<Chat> chats = [
    Chat(
      name: 'Aarav Sharma',
      message: 'Bro, project ka update bhej dena.',
      time: '9:42 AM',
      color: Color(0xFF5478C8),
      unread: 2,
      online: true,
    ),
    Chat(
      name: 'Priya Singh',
      message: 'Voice message',
      time: '9:30 AM',
      color: Color(0xFFB46B91),
      unread: 1,
      online: true,
    ),
    Chat(
      name: 'Placement Group',
      message: 'Rahul: Interview schedule aa gaya!',
      time: '9:15 AM',
      color: Color(0xFFDB9850),
      unread: 5,
    ),
    Chat(
      name: 'Rahul Verma',
      message: 'Thanks bhai ðŸ™Œ',
      time: 'Yesterday',
      color: Color(0xFF478F82),
    ),
    Chat(
      name: 'Neha Kumari',
      message: 'Photo',
      time: 'Yesterday',
      color: Color(0xFF896CC0),
    ),
    Chat(
      name: 'Project Team',
      message: 'You: Meeting at 6 PM',
      time: 'Monday',
      color: Color(0xFF6489A5),
    ),
    Chat(
      name: 'Aman Kumar',
      message: 'See you tomorrow!',
      time: 'Monday',
      color: Color(0xFFC47759),
    ),
  ];

  List<Chat> get filteredChats => chats
      .where((chat) => chat.name.toLowerCase().contains(search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
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

          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && context.mounted) {
                await widget.onLogout();
              }
            },
            icon: const Icon(Icons.logout_rounded),
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
          buildSimplePage(
            Icons.settings_outlined,
            'Settings',
            'Profile, privacy and notification settings.',
          ),
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
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
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
  }

  Widget buildChatsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
          child: TextField(
            onChanged: (value) => setState(() => search = value),
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
          child: filteredChats.isEmpty
              ? const Center(child: Text('No conversations found'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredChats.length,
                  separatorBuilder: (context, index) => const Padding(
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
                              chat.name[0],
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
                              color: chat.unread > 0
                                  ? waveGreen
                                  : Colors.black45,
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
                          MaterialPageRoute(
                            builder: (_) => ChatPage(chat: chat),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildSimplePage(IconData icon, String title, String description) {
    return Center(
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
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
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
  }

  void showNewChatDialog(BuildContext context) {
    final controller = TextEditingController();
    final api = ApiService();

    bool creating = false;
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the email address of a registered WaveChat user.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                enabled: !creating,
                decoration: const InputDecoration(
                  labelText: 'User email',
                  hintText: 'friend@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onSubmitted: (_) {},
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(dialogError!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: creating
                  ? null
                  : () async {
                      final email = controller.text.trim().toLowerCase();

                      if (email.isEmpty || !email.contains('@')) {
                        setDialogState(() {
                          dialogError = 'Enter a valid email address.';
                        });
                        return;
                      }

                      setDialogState(() {
                        creating = true;
                        dialogError = null;
                      });

                      try {
                        final result = await api.createConversation(
                          email: email,
                        );

                        final conversation =
                            result['conversation'] as Map<String, dynamic>;
                        final otherUser =
                            result['otherUser'] as Map<String, dynamic>;

                        final conversationId =
                            conversation['conversationId'] as String;
                        final name =
                            (otherUser['name'] as String?)?.trim().isNotEmpty ==
                                true
                            ? (otherUser['name'] as String).trim()
                            : email;

                        if (!mounted) return;

                        final existingIndex = chats.indexWhere(
                          (chat) => chat.conversationId == conversationId,
                        );

                        if (existingIndex == -1) {
                          setState(() {
                            chats.insert(
                              0,
                              Chat(
                                name: name,
                                message: 'Start a conversation',
                                time: 'Now',
                                color: const Color(0xFF478F82),
                                conversationId: conversationId,
                              ),
                            );
                            selectedTab = 0;
                            search = '';
                          });
                        } else {
                          setState(() {
                            selectedTab = 0;
                            search = '';
                          });
                        }

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          dialogError = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                          creating = false;
                        });
                      }
                    },
              child: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  final api = ApiService();
  final List<Map<String, dynamic>> messages = [];

  bool loading = true;
  bool sending = false;
  String? error;
  String? pendingClientMessageId;
  String? pendingMessageText;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await api.fetchMessages(
        conversationId: widget.chat.conversationId,
      );
      if (!mounted) return;

      setState(() {
        messages
          ..clear()
          ..addAll(result);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
      // Retry: reuse the same ID for the same message.
      clientMessageId = pendingClientMessageId!;
    } else {
      // New or edited message: generate a fresh ID.
      clientMessageId = '${DateTime.now().microsecondsSinceEpoch}-shivam';

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
        senderId: 'shivam',
      );

      if (!mounted) return;

      setState(() {
        final messageId = message['id'];

        if (!messages.any((item) => item['id'] == messageId)) {
          messages.add(message);
        }

        widget.chat.message = text;
        widget.chat.time = 'Now';
        controller.clear();

        pendingClientMessageId = null;
        pendingMessageText = null;

        sending = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        sending = false;
        error = 'Message send nahi hua. Connection check karo aur retry karo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      final isMine = sender == 'shivam';

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
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
                          child: Text(text),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
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
          ),
        ],
      ),
    );
  }
}
