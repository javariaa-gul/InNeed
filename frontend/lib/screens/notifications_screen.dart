import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final NotificationService notifs;
  const NotificationsScreen({super.key, required this.notifs});

  IconData _icon(String type) {
    switch (type) {
      case 'bid':
        return Icons.gavel_rounded;
      case 'offer':
        return Icons.swap_horiz_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'status':
        return Icons.timeline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'bid':
        return kBlue;
      case 'offer':
        return kOrange;
      case 'chat':
        return kPurple;
      case 'review':
        return Colors.amber;
      case 'status':
        return kGreen;
      default:
        return kGrey;
    }
  }

  void _handleNotificationTap(BuildContext context, NotificationItem item) {
    notifs.markRead(item.id);

    // Navigate based on notification type
    final data = item.data ?? {};
    switch (item.type) {
      case 'chat':
        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              jobId: data['jobId'] as int? ?? 0,
              otherUserId: data['otherUserId'] as int? ?? 0,
              otherName: data['otherName'] as String? ?? 'User',
            ),
          ),
        );
        break;
      case 'bid':
      case 'offer':
        // Navigate to bids screen or dashboard bids tab
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case 'review':
        // Navigate to reviews screen
        Navigator.of(context).pushReplacementNamed('/profile');
        break;
      case 'status':
        // Navigate to active job screen
        Navigator.of(context).pushReplacementNamed('/active-job');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifs,
      builder: (context, _) {
        final items = notifs.notifications;
        return CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: kBlack,
            automaticallyImplyLeading: false,
            title: const Text('Notifications',
                style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: notifs.markAllRead,
                  child: const Text('Mark all read',
                      style: TextStyle(color: Color(0xFFF9F77E), fontSize: 12)),
                ),
            ],
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            color: kBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: kDivider, width: 2)),
                        child: const Icon(Icons.notifications_none_rounded,
                            color: kGrey, size: 38),
                      ),
                      const SizedBox(height: 20),
                      const Text('No Notifications Yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kBlack)),
                      const SizedBox(height: 8),
                      const Text("You'll see updates about your jobs here",
                          style: TextStyle(fontSize: 14, color: kGrey),
                          textAlign: TextAlign.center),
                    ]),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  final color = _color(item.type);
                  return GestureDetector(
                    onTap: () => _handleNotificationTap(context, item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? kWhite
                            : const Color(0xFFF9F77E).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: kShadow,
                        border: item.isRead
                            ? null
                            : Border.all(
                                color: const Color(0xFFF9F77E)
                                    .withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(_icon(item.type), color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.title,
                                  style: TextStyle(
                                      fontWeight: item.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      fontSize: 14,
                                      color: kBlack)),
                              const SizedBox(height: 3),
                              Text(item.body,
                                  style: const TextStyle(
                                      color: kGrey, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(_timeAgo(item.createdAt),
                                  style: const TextStyle(
                                      color: kGrey, fontSize: 10)),
                            ])),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFF9F77E),
                                shape: BoxShape.circle),
                          ),
                      ]),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
