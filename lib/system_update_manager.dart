import 'system_update.dart';

class SystemUpdateManager {
  static final List<SystemUpdate>
      updates = [];

  static void addUpdate({
    required String title,
    required String description,
    required String type,
  }) {
    updates.insert(
      0,
      SystemUpdate(
        title: title,
        description: description,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
  }

  static int get unreadCount {
    return updates
        .where(
          (update) =>
              !update.isRead,
        )
        .length;
  }

  static void markAllRead() {
    for (final update
        in updates) {
      update.isRead = true;
    }
  }
}