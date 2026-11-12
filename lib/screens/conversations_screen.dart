import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import '../app_theme.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    if (currentUserId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allMessages =
          List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> uniqueContacts = {};

      for (var msg in allMessages) {
        String senderId = msg['sender_id'];
        String receiverId = msg['receiver_id'];
        String otherUserId =
            (senderId == currentUserId) ? receiverId : senderId;

        if (!uniqueContacts.containsKey(otherUserId)) {
          uniqueContacts[otherUserId] = {
            'user_id': otherUserId,
            'last_message': msg['message'],
            'created_at': msg['created_at'],
          };
        }
      }

      List<Map<String, dynamic>> loadedConversations = [];

      if (uniqueContacts.isNotEmpty) {
        final uids = uniqueContacts.keys.toList();
        Map<String, String> customerNames = {};
        try {
          final customersRes = await Supabase.instance.client
              .from('customers')
              .select('id, username, full_name')
              .inFilter('id', uids);
          for (var c in customersRes) {
            final name = c['username'] ?? c['full_name'] ?? 'مستخدم';
            customerNames[c['id'].toString()] = name.toString();
          }
        } catch (_) {}

        final missingIds =
            uids.where((id) => !customerNames.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final profilesRes = await Supabase.instance.client
                .from('profiles')
                .select('id, username, full_name')
                .inFilter('id', missingIds);
            for (var p in profilesRes) {
              final name = p['username'] ?? p['full_name'] ?? 'مستخدم';
              customerNames[p['id'].toString()] = name.toString();
            }
          } catch (_) {}
        }

        for (var entry in uniqueContacts.values) {
          final uid = entry['user_id'] as String;
          loadedConversations.add({
            'user_id': uid,
            'name': customerNames[uid] ?? 'مستخدم / تاجر',
            'last_message': entry['last_message'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _conversations = loadedConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('محادثات الدعم والتجار',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _conversations.isEmpty
              ? const Center(
                  child: Text(
                      'لا توجد محادثات سابقة، ابدأ التواصل من تفاصيل القطع المعروضة!',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14)),
                      child: Material(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            child: Text(
                                convo['name'].isNotEmpty
                                    ? convo['name'][0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(convo['name'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          subtitle: Text(convo['last_message'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: Colors.grey, size: 14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                    receiverId: convo['user_id'],
                                    receiverName: convo['name']),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
