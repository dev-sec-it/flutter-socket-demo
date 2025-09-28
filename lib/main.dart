import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();

  void _joinChat() {
    final username = _usernameController.text.trim();
    final roomId = _roomIdController.text.trim();

    if (username.isEmpty || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both username and room ID')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(username: username, roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Chat Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _joinChat,
              child: const Text('Join Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String roomId;

  const ChatScreen({super.key, required this.username, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late WebSocketChannel channel;
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      // Connect to your WebSocket server
      channel = WebSocketChannel.connect(
        Uri.parse(
          'wss://chat.vidioconnect.com/?username=${widget.username}&roomId=${widget.roomId}',
        ),
      );

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;

            if (data.containsKey('system')) {
              setState(() {
                _messages.add({'type': 'system', 'text': data['system']});
              });
            } else if (data.containsKey('username') &&
                data.containsKey('message')) {
              setState(() {
                _messages.add({
                  'type': 'message',
                  'username': data['username'],
                  'text': data['message'],
                });
              });
            } else if (data.containsKey('error')) {
              setState(() {
                _messages.add({'type': 'error', 'text': data['error']});
              });
            }
          } catch (e) {
            setState(() {
              _messages.add({
                'type': 'error',
                'text': 'Invalid message received',
              });
            });
          }
        },
        onError: (error) {
          setState(() {
            _messages.add({
              'type': 'error',
              'text': 'Connection error: $error',
            });
            _connected = false;
          });
        },
        onDone: () {
          setState(() {
            _messages.add({
              'type': 'system',
              'text': 'Disconnected from server',
            });
            _connected = false;
          });
        },
      );

      setState(() {
        _connected = true;
        _messages.add({'type': 'system', 'text': 'Connected to server'});
      });
    } catch (e) {
      setState(() {
        _messages.add({'type': 'error', 'text': 'Failed to connect: $e'});
        _connected = false;
      });
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      channel.sink.add(jsonEncode({'message': text}));
      _textController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room: ${widget.roomId}'),
        backgroundColor: _connected ? Colors.blue : Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectToWebSocket,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final type = message['type'];
                final text = message['text'];

                if (type == 'system') {
                  return ListTile(
                    title: Text(
                      text,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    dense: true,
                  );
                } else if (type == 'error') {
                  return ListTile(
                    title: Text(
                      'Error: $text',
                      style: const TextStyle(color: Colors.red),
                    ),
                    dense: true,
                  );
                } else {
                  final username = message['username'];
                  final isMe = username == widget.username;

                  return Container(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      color: isMe ? Colors.blue[100] : Colors.grey[100],
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : username ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? Colors.blue[800]
                                    : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(text),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _connected ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
