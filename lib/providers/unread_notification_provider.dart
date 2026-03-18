import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fund_notification_providers.dart';

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(fundNotificationRepositoryProvider);
  return repo.getUnreadCount();
});
