import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <- potrzebne do SystemUiOverlayStyle
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserPhone;

  const ChatScreen({
    required this.chatId,
    required this.currentUserPhone,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.length == 9) return '+48$phone';
    return phone;
  }

  String _getRecipientPhone() {
    final parts = widget.chatId.split('-');
    if (parts.length != 2) return "Nieznany adresat";
    String p1 = normalizePhoneNumber(parts[0]);
    String p2 = normalizePhoneNumber(parts[1]);
    return p1 == normalizePhoneNumber(widget.currentUserPhone) ? p2 : p1;
  }

  Future<String> getUserName(String phone) async {
    phone = normalizePhoneNumber(phone);
    if (phone == normalizePhoneNumber(widget.currentUserPhone)) return "Ty";
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data()! as Map<String, dynamic>;
        return userData['name'] ?? phone;
      }
      return phone;
    } catch (_) {
      return phone;
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final me = normalizePhoneNumber(widget.currentUserPhone);
    final other = normalizePhoneNumber(_getRecipientPhone());
    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    final msg = {
      'sender': me,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await chatRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [me, other],
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add(msg);
      messageController.clear();

      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Błąd wysyłania: $e")));
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipient = normalizePhoneNumber(_getRecipientPhone());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: FutureBuilder<String>(
          future: getUserName(recipient),
          builder: (ctx, snap) {
            final title = (snap.connectionState == ConnectionState.waiting)
                ? "Ładowanie..."
                : (snap.data ?? recipient);
            return Text(title, style: const TextStyle(color: Colors.white));
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient w tle
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6B3FA5), // intensywne fioletowe u góry
                    Color(0xFF4B2E7D), // nieco ciemniejszy
                    Color(0xFF1F0F3B), // głęboki granat
                    Color(0xFF000000), // czerń na dole
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Właściwa zawartość
          Column(
            children: [
              SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text("Błąd: ${snap.error}",
                            style: const TextStyle(color: Colors.white)),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("Brak wiadomości",
                            style: TextStyle(color: Colors.white)),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final data =
                        docs[i].data() as Map<String, dynamic>;
                        final isMe = data['sender'] ==
                            normalizePhoneNumber(widget.currentUserPhone);

                        String time = "";
                        if (data['timestamp'] is Timestamp) {
                          time = DateFormat('dd.MM.yyyy HH:mm')
                              .format((data['timestamp'] as Timestamp).toDate());
                        }

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: getUserName(data['sender']),
                                  builder: (c, s) {
                                    final n = s.data ?? data['sender'];
                                    return Text(n,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey));
                                  },
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF8D6DC4) // Twoja purpurowa „ja” wiadomość
                                        : const Color(0xFF333333), // ciemniejsze bąbelki rozmówcy
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    data['text'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ),

                                const SizedBox(height: 2),
                                Text(time,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Napisz wiadomość…",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
