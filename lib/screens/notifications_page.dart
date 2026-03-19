import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fund_notification_providers.dart';
import '../providers/unread_notification_provider.dart';
import 'expenses_page.dart';
import 'invoice_detail_page.dart';
import 'payment_review_detail_page.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      case 'expense_comment':
        return Icons.chat_bubble_outline;
      case 'invoice':
        return Icons.receipt_long_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _formatCreatedAt(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$h:$m $d/$mo/$y';
    } catch (_) {
      return raw;
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _subtitleFor(Map<String, dynamic> n) {
    final message = (n['message'] as String?)?.trim() ?? '';
    if (message.isNotEmpty) return message;

    final data = _asMap(n['data']);
    final event = (data['event'] as String?) ?? '';
    final dueDate = (data['due_date'] as String?) ?? '';
    final createdAtRaw = (n['created_at'] as String?) ?? '';
    final createdAtText = _formatCreatedAt(createdAtRaw);

    switch (event) {
      case 'submitted':
        return 'Có phiếu nộp mới cần xem';
      case 'verified':
        return 'Phiếu nộp của bạn đã được duyệt';
      case 'rejected':
        return 'Phiếu nộp của bạn đã bị từ chối';
      case 'invalidated':
        return 'Phiếu nộp của bạn bị đánh dấu không hợp lệ';
      case 'due_soon':
        return dueDate.isNotEmpty
            ? 'Sắp đến hạn: $dueDate'
            : 'Hóa đơn sắp đến hạn thanh toán';
      case 'overdue':
        return dueDate.isNotEmpty
            ? 'Đã quá hạn từ: $dueDate'
            : 'Hóa đơn đã quá hạn thanh toán';
      case 'generated':
        return 'Kỳ thu đã được phát hành hóa đơn';
      case 'created':
        return 'Có khoản chi mới trong lớp';
      case 'commented':
        return 'Có bình luận mới ở khoản chi';
      default:
        return createdAtText.isNotEmpty ? createdAtText : 'Nhấn để xem chi tiết';
    }
  }

  Future<void> _openByNotification(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final type = (item['type'] as String?) ?? '';
    final data = _asMap(item['data']);
    final event = (data['event'] as String?) ?? '';

    if (type == 'income') {
      final paymentId = _toInt(data['payment_id']);
      final invoiceId = _toInt(data['invoice_id']);

      if (event == 'submitted' && paymentId > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentReviewDetailPage(paymentId: paymentId),
          ),
        );
        return;
      }

      if (invoiceId > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailPage(invoiceId: invoiceId),
          ),
        );
        return;
      }
    }

    if (type == 'invoice') {
      final invoiceId = _toInt(data['invoice_id']);
      final classId = _toInt(data['class_id']);
      final feeCycleId = _toInt(data['fee_cycle_id']);

      if (invoiceId > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailPage(invoiceId: invoiceId),
          ),
        );
        return;
      }

      if (event == 'generated' && classId > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpensesPage(
              classId: classId,
              feeCycleId: feeCycleId > 0 ? feeCycleId : null,
            ),
          ),
        );
        return;
      }
    }

    if (type == 'expense' || type == 'expense_comment') {
      final classId = _toInt(data['class_id']);
      final feeCycleId = _toInt(data['fee_cycle_id']);

      if (classId > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpensesPage(
              classId: classId,
              feeCycleId: feeCycleId > 0 ? feeCycleId : null,
            ),
          ),
        );
        return;
      }
    }
  }

  Future<void> _handleTap(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> n,
      ) async {
    final repo = ref.read(fundNotificationRepositoryProvider);
    final id = _toInt(n['id']);

    try {
      if (id > 0) {
        await repo.markAsRead(id);
      }

      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);

      if (!context.mounted) return;
      await _openByNotification(context, n);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật thông báo: $e')),
      );
    }
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(fundNotificationRepositoryProvider);
      await repo.markAllAsRead();

      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đánh dấu đã đọc: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifs = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            icon: const Icon(Icons.mark_email_read_outlined),
            onPressed: () => _markAllAsRead(context, ref),
          ),
        ],
      ),
      body: asyncNotifs.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Chưa có thông báo nào'),
            );
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = _asMap(list[index]);
              final isRead = (n['is_read'] as bool?) ?? false;
              final type = (n['type'] as String?) ?? '';
              final title = (n['title'] as String?) ?? '';
              final subtitle = _subtitleFor(n);

              return ListTile(
                leading: Icon(_iconForType(type)),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isRead ? null : const Icon(Icons.circle, size: 10),
                onTap: () => _handleTap(context, ref, n),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Lỗi tải thông báo: $e'),
        ),
      ),
    );
  }
}