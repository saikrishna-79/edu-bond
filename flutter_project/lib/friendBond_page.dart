import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class FriendBond extends StatefulWidget {
  final String friendUsername;
  final String username;
  final String course;

  const FriendBond({
    Key? key,
    required this.friendUsername,
    required this.username,
    required this.course,
  }) : super(key: key);

  @override
  _FriendBondState createState() => _FriendBondState();
}

class _FriendBondState extends State<FriendBond> {
  List<Map<String, dynamic>> _messages = [];
  TextEditingController _messageController = TextEditingController();
  Timer? _timer;

  Future<void> fetchMessages() async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/api/messages/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender': widget.username,
        'receiver': widget.friendUsername,
        'course': widget.course,
      }),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        _messages = data.map((item) {
          return {
            "username": item['username'],
            "text": item['text'],
            "files": item['files'] ?? [],
          };
        }).toList();
      });
    } else {
      throw Exception('Failed to load messages: ${response.body}');
    }
  }

  void startFetchingMessages() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      fetchMessages();
    });
  }

  @override
  void initState() {
    super.initState();
    fetchMessages();
    startFetchingMessages();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    final response = await http.post(
      Uri.parse('http://localhost:3000/api/send-message'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender': widget.username,
        'receiver': widget.friendUsername,
        'course': widget.course,
        'text': message,
      }),
    );

    if (response.statusCode == 200) {
      _messageController.clear();
      fetchMessages();
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<void> uploadFile(Uint8List bytes, String filename) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:3000/api/send-message'),
    );

    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    request.fields['sender'] = widget.username;
    request.fields['receiver'] = widget.friendUsername;
    request.fields['course'] = widget.course;

    var response = await request.send();

    if (response.statusCode == 200) {
      print('File uploaded successfully');
      fetchMessages();
    } else {
      throw Exception('Failed to upload file: ${response.statusCode}');
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      Uint8List? bytes = result.files.single.bytes;
      String? filename = result.files.single.name;

      if (bytes != null && filename != null) {
        await uploadFile(bytes, filename);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              widget.friendUsername,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF2A2A3C),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isCurrentUser = message['username'] == widget.username;

                return Container(
                  margin: EdgeInsets.only(
                    bottom: 16,
                    left: isCurrentUser ? 64 : 0,
                    right: isCurrentUser ? 0 : 64,
                  ),
                  child: Column(
                    crossAxisAlignment: isCurrentUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if ((message['text'] ?? '').isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? Color(0xFF4B4BF7)
                                : Color(0xFF2A2A3C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      if (message['files'].isNotEmpty) ...[
                        SizedBox(height: 8),
                        ...message['files'].map<Widget>((file) {
                          return Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Color(0xFF4B4BF7)
                                  : Color(0xFF2A2A3C),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        file['filename'],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.download,
                                          size: 18, color: Colors.blue),
                                      label: Text(
                                        'Download',
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                      onPressed: () => downloadFile(
                                          file['filePath'], file['filename']),
                                      style: TextButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.1),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: Icon(Icons.visibility,
                                          size: 18, color: Colors.blue),
                                      label: Text(
                                        'View',
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                      onPressed: () =>
                                          viewFile(file['filename']),
                                      style: TextButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.1),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          ' ',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A3C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: Colors.white70),
                  onPressed: pickFile,
                  padding: EdgeInsets.all(12),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {},
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Color(0xFF1E1E2E),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (text) {
                        sendMessage(text);
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF4B4BF7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () => sendMessage(_messageController.text),
                    padding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> downloadFile(String filePath, String filename) async {
    String url = 'http://localhost:3000/api/download/$filename';

    try {
      if (kIsWeb) {
        final anchor = html.AnchorElement(href: url);
        anchor.setAttribute('download', filename);
        anchor.click();
      } else {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            String path = '${directory.path}/$filename';
            io.File file = io.File(path);
            await file.writeAsBytes(response.bodyBytes);
          } else {
            print('Failed to get the directory for saving the file.');
          }
        } else {
          print('Failed to download file: ${response.statusCode}');
          throw Exception('Failed to download file');
        }
      }
    } catch (e) {
      print('Error downloading file: $e');
    }
  }

  Future<void> viewFile(String filename) async {
    final url = 'http://localhost:3000/api/view/$filename';
    if (kIsWeb) {
      html.window.open(url, '_blank');
    } else {
      Uri uri = Uri.parse(url);
      if (await canLaunch(uri.toString())) {
        await launch(uri.toString());
      } else {
        throw 'Could not launch $url';
      }
    }
  }
}
s
