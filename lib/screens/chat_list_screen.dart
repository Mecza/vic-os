import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final String currentUserId;
  const ChatListScreen({required this.currentUserId, Key? key})
      : super(key: key);

  String normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.length == 9) return '+48$phone';
    return phone;
  }

  String _getOtherParticipant(Map<String, dynamic> chatData) {
    final parts = (chatData['participants'] as List).cast<String>();
    final me = normalizePhoneNumber(currentUserId);
    return parts.firstWhere(
          (p) => normalizePhoneNumber(p) != me,
      orElse: () => me,
    );
  }

  Future<String> _getUserName(String phone) async {
    final normalized = normalizePhoneNumber(phone);
    if (normalized == normalizePhoneNumber(currentUserId)) return "Ty";
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: normalized)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data() as Map<String, dynamic>;
        return d['name'] ?? normalized;
      }
    } catch (_) {}
    return normalized;
  }

  Color _generateColor(String id) {
    final h = id.hashCode;
    return Color.fromARGB(
      255,
      (h & 0xFF) % 200,
      ((h >> 8) & 0xFF) % 200,
      ((h >> 16) & 0xFF) % 50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = normalizePhoneNumber(currentUserId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Twoje rozmowy",
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6B3FA5),
                Color(0xFF4B2E7D),
                Color(0xFF1F0F3B),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: me)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                "Błąd: ${snap.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Brak rozmów",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: kToolbarHeight + MediaQuery.of(context).padding.top,
            ),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 1),
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              final other = _getOtherParticipant(data);
              final lastMsg = data['lastMessage'] ?? '';
              String time = '';
              if (data['lastMessageTimestamp'] is Timestamp) {
                time = DateFormat('dd.MM HH:mm')
                    .format((data['lastMessageTimestamp'] as Timestamp).toDate());
              }
              final nameFut = _getUserName(other);
              final isSelf = normalizePhoneNumber(other) == me;

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: docs[i].id,
                      currentUserPhone: currentUserId,
                    ),
                  ),
                ),
                child: Container(
                  color: isSelf
                      ? Colors.lightBlueAccent.withOpacity(0.3)
                      : Colors.transparent,
                  padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: _generateColor(other),
                        child: FutureBuilder<String>(
                          future: nameFut,
                          builder: (_, s) {
                            final l = (s.connectionState == ConnectionState.done && s.data != null)
                                ? s.data![0].toUpperCase()
                                : other[0].toUpperCase();
                            return Text(
                              l,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: nameFut,
                              builder: (_, s) {
                                final n = (s.connectionState == ConnectionState.done && s.data != null)
                                    ? s.data!
                                    : other;
                                return Text(
                                  n,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                            const SizedBox(height: 5),
                            Text(
                              lastMsg,
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
