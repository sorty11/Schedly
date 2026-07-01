const fs = require('fs');
let c = fs.readFileSync('lib/home_page.dart', 'utf8');

if (!c.includes('import \'dart:async\';')) {
  c = c.replace(/import 'package:flutter\/material.dart';/, "import 'dart:async';\nimport 'package:flutter/material.dart';");
}

c = c.replace(/int _unreadCount = 0;/, "int _unreadCount = 0;\n  StreamSubscription? _notificationsSubscription;");

c = c.replace(/FirebaseFirestore\.instance\s*\.collection\('sections'\)\s*\.doc\(widget\.division\)\s*\.collection\('notifications'\)\s*\.snapshots\(\)\s*\.listen\(\(\_\) \=\> \_loadUnreadCount\(\)\);/, 
`_notificationsSubscription = FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.division)
        .collection('notifications')
        .snapshots()
        .listen((_) => _loadUnreadCount());`);

c = c.replace(/Widget build\(BuildContext context\) \{/, 
`@override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {`);

fs.writeFileSync('lib/home_page.dart', c);
console.log('Fixed memory leak in home_page.dart correctly');
