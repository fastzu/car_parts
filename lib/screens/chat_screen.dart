import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? productId;

  const ChatScreen(
      {super.key,
      required this.receiverId,
      required this.receiverName,
      this.productId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _messagesChannel = _subscribeToMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.receiverId}),and(sender_id.eq.${widget.receiverId},receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = response
              .map<Map<String, dynamic>>(
                  (item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching messages: $e');
    }
  }

  RealtimeChannel _subscribeToMessages() {
    return _supabase
        .channel('public:messages_realtime_${widget.receiverId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = payload.newRecord;
            final currentUserId = _supabase.auth.currentUser?.id;
            if ((newMsg['sender_id'] == widget.receiverId &&
                    newMsg['receiver_id'] == currentUserId) ||
                (newMsg['sender_id'] == currentUserId &&
                    newMsg['receiver_id'] == widget.receiverId)) {
              if (mounted) {
                setState(() {
                  if (!_messages.any((m) => m['id'] == newMsg['id'])) {
                    _messages.add(newMsg);
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final Map<String, dynamic> messageData = {
        'sender_id': currentUserId,
        'receiver_id': widget.receiverId,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (widget.productId != null) {
        messageData['product_id'] = widget.productId;
      }

      final res = await _supabase
          .from('messages')
          .insert(messageData)
          .select()
          .single();

      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m['id'] == res['id'])) {
            _messages.add(res);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في إرسال الرسالة: $e'),
          backgroundColor: AppTheme.error));
    }
  }

  @override
  void dispose() {
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(widget.receiverName,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('لا توجد رسائل سابقة، ابدأ المحادثة الآن!',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == currentUserId;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg['message'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                    icon:
                        const Icon(Icons.send_rounded, color: AppTheme.primary),
                    onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
