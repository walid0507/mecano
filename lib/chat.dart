import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final Dio dio = Dio();
  int? userId;
  bool _loading = true;
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndHistory();
  }

  Future<void> _loadUserAndHistory() async {
    try {
      // Récupère l'utilisateur connecté
      final meResp = await dio.get(
        'http://localhost:3000/users/me',
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      userId = meResp.data['id'];
      // Récupère l'historique du chat
      final histResp = await dio.get(
        'http://localhost:3000/chatbot/$userId/history',
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      final history = histResp.data['history'] as List;
      setState(() {
        _messages.clear();
        for (final h in history) {
          _messages.add({'sender': 'user', 'text': h['input_text'] ?? ''});
          _messages.add({'sender': 'robot', 'text': h['response_text'] ?? ''});
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'robot',
          'text': "Erreur lors du chargement de l'historique : $e"
        });
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || userId == null) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
    });
    try {
      final resp = await dio.post(
        'http://localhost:3000/chatbot',
        data: {'message': text, 'userId': userId.toString()},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: {'withCredentials': true},
        ),
      );
      final botReply = resp.data['response'] ?? 'Le robot n\'a pas répondu.';
      setState(() {
        _messages.add({'sender': 'robot', 'text': botReply});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'robot', 'text': 'Erreur lors de l\'envoi : $e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFAB40),
        title: const Text(
          'Chat avec le robot',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['sender'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFFFFAB40)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Écrivez votre message...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
