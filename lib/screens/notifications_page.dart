import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fund_notification_providers.dart';
import '../providers/unread_notification_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'invoice':
        return Icons.receipt_long_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _subtitleFor(Map<String, dynamic> item) {
    final amount = item['amount'];
    final event = (item['event'] ?? '').toString();

    if (amount is num && amount > 0) {
      final pretty = amount.toStringAsFixed(0);
      if (event == 'invoice_generated') return 'Số tiền: $pretty đ';
      return 'Số tiền: $pretty đ';
    }

    return (item['title'] ?? '').toString();
  }

  String _formatCreatedAt(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(notificationsProvider);
    final repo = ref.read(fundNotificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Các thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: () async {
              await repo.markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: asyncItems.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có thông báo nào'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = item['id'] as int;
                final isRead = item['read'] == true;
                final title = (item['title'] ?? '').toString();
                final createdAt = _formatCreatedAt((item['created_at'] ?? '').toString());

                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(_iconForType((item['type'] ?? '').toString())),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(_subtitleFor(item)),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(createdAt),
                      ],
                    ],
                  ),
                  trailing: !isRead
                      ? const Icon(Icons.circle, size: 10, color: Colors.red)
                      : null,
                  onTap: () async {
                    await repo.markAsRead(id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải thông báo: $e')),
      ),
    );
  }
}
