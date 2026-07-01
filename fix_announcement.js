const fs = require('fs');
let c = fs.readFileSync('lib/create_announcement_page.dart', 'utf8');

c = c.replace(/String priority = 'Normal';/, "String priority = 'Normal';\n  bool _isPublishing = false;");

c = c.replace(/Future\<void\> \_publish\(\) async \{([\s\S]*?)debugPrint\('ANNOUNCEMENT ERROR: \$e'\);\n    \}/, 
`Future<void> _publish() async {
    if (_isPublishing) return;
    
    if (titleController.text.isEmpty ||
        messageController.text.isEmpty) {
      return;
    }

    setState(() { _isPublishing = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final sectionId = prefs.getString('section_id') ?? prefs.getString('selected_division');

      if (sectionId == null) {
        setState(() { _isPublishing = false; });
        return;
      }

      await AnnouncementService.createAnnouncement(
        title: titleController.text,
        message: messageController.text,
        priority: priority,
        sectionId: sectionId,
      );
      await AppNotificationService.createNotification(
        title: 'New Announcement',
        message: messageController.text,
        division: sectionId,
        type: 'announcement',
      );
      if (!mounted) return;

      AppDialogs.showSnackBar(
        context: context,
        message: 'Announcement published for $sectionId',
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Publish Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() { _isPublishing = false; });
    }`);

c = c.replace(/onPressed: _publish,/, "onPressed: _isPublishing ? null : _publish,");
c = c.replace(/child: Row\(\s*mainAxisAlignment: MainAxisAlignment.center,\s*children: \[\s*const Icon\(Icons.send_rounded\),\s*const SizedBox\(width: 8\),\s*const Text\('Publish Announcement', style: TextStyle\(fontSize: 16, fontWeight: FontWeight.w700\)\),\s*\],\s*\),/,
`child: _isPublishing 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded),
                        const SizedBox(width: 8),
                        const Text('Publish Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),`);

fs.writeFileSync('lib/create_announcement_page.dart', c);
console.log('Fixed create_announcement_page.dart');
