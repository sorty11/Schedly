import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schedly/widgets/animations/animated_card.dart';
import 'package:schedly/widgets/app_dialogs.dart';

import '../app_settings.dart';
import '../theme/theme.dart';

class BatchManagementPage extends StatefulWidget {
  const BatchManagementPage({super.key});

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  bool _isLoading = true;
  List<String> _batches = [];
  Map<String, String> _batchNames = {};

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sections')
          .doc(AppSettings.division)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _batches = List<String>.from(data['batches'] ?? []);
        if (data.containsKey('batchNames')) {
          _batchNames = Map<String, String>.from(data['batchNames'] as Map);
        } else {
          _batchNames = {};
        }
      }
    } catch (e) {
      debugPrint('Error fetching batches: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBatchNames() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await FirebaseFirestore.instance
          .collection('sections')
          .doc(AppSettings.division)
          .update({'batchNames': _batchNames});
      if (!mounted) return;
      Navigator.pop(context);
      AppDialogs.showSnackBar(
        context: context,
        message: 'Batch names updated successfully',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AppDialogs.showSnackBar(
        context: context,
        message: 'Failed to update batch names',
        isError: true,
      );
    }
  }

  void _editBatchName(String batchId) {
    final controller = TextEditingController(
      text: _batchNames[batchId] ?? batchId,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rename $batchId',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Batch Name',
            hintText: 'e.g., Batch Alpha',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (controller.text.trim().isEmpty ||
                    controller.text.trim() == batchId) {
                  _batchNames.remove(batchId);
                } else {
                  _batchNames[batchId] = controller.text.trim();
                }
              });
              Navigator.pop(ctx);
              _saveBatchNames();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Reset to Default',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to remove all custom batch names? This will restore the default IDs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _batchNames.clear();
              });
              Navigator.pop(ctx);
              _saveBatchNames();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Batches',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          if (_batchNames.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              tooltip: 'Reset to default',
              onPressed: _resetToDefault,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty ||
                (_batches.length == 1 && _batches.first == 'Whole Class')
          ? const Center(child: Text('No split batches defined in section.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              itemCount: _batches.length,
              itemBuilder: (context, index) {
                final batchId = _batches[index];
                if (batchId == 'Whole Class') return const SizedBox.shrink();
                final customName = _batchNames[batchId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AnimatedCard(
                    onTap: () => _editBatchName(batchId),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: sem.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(Icons.group_rounded, color: cs.primary),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customName ?? batchId,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (customName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Original ID: $batchId',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: sem.onSurfaceMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit_rounded,
                            color: sem.onSurfaceFaint,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
