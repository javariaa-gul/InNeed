import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import 'active_job_screen.dart';
import 'profile_screen.dart';
import 'poster_home_screen.dart';
import 'seeker_home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _notifs = NotificationService();
  int _tab = 0;
  bool _loading = true, _switching = false;
  Map<String, dynamic>? _user;

  String get _role => _user?['activeRole']?.toString() ?? 'worker';
  bool get _isPoster => _role == 'employer';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cached = await StorageService.getCachedUser();
      if (cached != null && mounted) setState(() => _user = cached);
    } catch (_) {}
    await _load();
    try {
      await SocketService().connect();
      _setupSockets();
    } catch (e) {
      debugPrint('Socket: $e');
    }
  }

  void _setupSockets() {
    SocketService().on('bid_accepted', (d) {
      if (!mounted) return;
      _notifs.addNotification(
          title: '🎉 Bid Accepted!',
          body: 'Your bid was accepted.',
          type: 'bid',
          data: d);
      showSnack(context, '🎉 Your bid was accepted!', ok: true);
    });

    SocketService().on('new_bid', (d) {
      if (!mounted) return;
      final name = d['seekerName'] ?? 'Someone';
      _notifs.addNotification(
          title: '📩 New Bid',
          body: '$name placed a bid on your job',
          type: 'bid',
          data: d);
    });

    SocketService().on('bid_updated', (data) {
      if (!mounted) return;
      final name = data['seekerName'] ?? 'Someone';
      _notifs.addNotification(
          title: '🔄 Counter Offer',
          body: '$name sent a counter offer',
          type: 'offer',
          data: data);
      _showCounterOfferDialog(data);
    });

    SocketService().on('job_relisted', (d) {
      if (!mounted) return;
      _notifs.addNotification(
          title: '🔄 Job Re-listed',
          body: 'A job was re-listed. You can bid again!',
          type: 'job',
          data: d);
    });

    SocketService().on('job_completed', (d) {
      if (!mounted) return;
      final jobId = d['jobId'] as int?;
      final revieweeId = d['revieweeId'] as int?;
      if (jobId != null && revieweeId != null) {
        _notifs.addNotification(
            title: '✅ Job Completed',
            body: 'Please leave a review.',
            type: 'review',
            data: d);
        Navigator.pushNamed(context, '/review', arguments: {
          'jobId': jobId,
          'revieweeId': revieweeId,
          'revieweeName': 'Other Party',
        });
      }
    });

    SocketService().on('counter_bid_accepted', (d) {
      if (!mounted) return;
      _notifs.addNotification(
          title: '✅ Counter Offer Accepted',
          body: 'Your counter offer was accepted! Job is now active.',
          type: 'offer',
          data: d);
      showSnack(context, '✅ Counter offer accepted!', ok: true);
      _load();
    });

    SocketService().on('counter_bid_rejected', (d) {
      if (!mounted) return;
      _notifs.addNotification(
          title: '❌ Counter Offer Rejected',
          body: 'Your counter offer was rejected.',
          type: 'offer',
          data: d);
      showSnack(context, '❌ Counter offer rejected.', err: true);
    });

    SocketService().on('message_received', (d) {
      if (!mounted) return;
      final senderId = d['senderId'] as int?;
      final jobId = d['jobId'] as int?;
      final message = d['message'] as String? ?? 'You received a message';

      _notifs.addNotification(
          title: '💬 New Message',
          body:
              message.length > 50 ? '${message.substring(0, 50)}...' : message,
          type: 'chat',
          data: {
            ...d,
            'otherUserId': senderId,
            'otherName': d['senderName'] ?? 'User',
          });
    });

    SocketService().on('job_status_updated', (d) {
      if (!mounted) return;
      _notifs.addNotification(
          title: '📊 Job Status Updated',
          body: 'Job progress has been updated',
          type: 'status',
          data: d);
    });
  }

  void _showCounterOfferDialog(Map<String, dynamic> data) {
    final previousPrice = data['previousPrice'];
    final newPrice = data['offeredPrice'];
    final seekerName = data['seekerName'] ?? 'Someone';
    final jobTitle = data['jobTitle'] ?? 'a job';
    final bidId = data['bidId'];
    final jobId = data['jobId'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  Icon(Icons.swap_horiz_rounded, color: Colors.amber.shade700)),
          const SizedBox(width: 12),
          const Text('Counter Offer!',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$seekerName sent a counter-offer for "$jobTitle"'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200)),
            child: Column(children: [
              Text('Previous: Rs. $previousPrice',
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough, color: kGrey)),
              const SizedBox(height: 8),
              Text('New Offer: Rs. $newPrice',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: kGreen)),
            ]),
          ),
          if (data['message'] != null) ...[
            const SizedBox(height: 12),
            Text('💬 "${data['message']}"',
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _api.rejectCounterBid(jobId, bidId);
                  if (mounted) showSnack(context, 'Counter offer rejected');
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), err: true);
                }
              },
              child: const Text('Reject', style: TextStyle(color: kRed))),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _api.acceptCounterBid(jobId, bidId);
                  if (mounted) {
                    showSnack(context, '✅ Accepted! Tracking started.',
                        ok: true);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ActiveJobScreen()));
                  }
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), err: true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen, foregroundColor: kWhite),
              child: const Text('Accept',
                  style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchRole() async {
    setState(() => _switching = true);
    try {
      final r = await _api.switchRole();
      if (mounted) {
        setState(() {
          _user?['activeRole'] = r['activeRole'];
          _tab = 0;
        });
        showSnack(context,
            'Switched to ${(r['activeRole'] as String).toUpperCase()} mode',
            ok: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _logout() async {
    SocketService().disconnect();
    _notifs.clear();
    await StorageService.clearAuthData();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return const Scaffold(
          backgroundColor: kBg,
          body: Center(child: CircularProgressIndicator(color: kBlack)));
    }
    return AnimatedBuilder(
      animation: _notifs,
      builder: (context, _) => Scaffold(
        backgroundColor: kBg,
        body: IndexedStack(
          index: _tab,
          children: [
            _isPoster
                ? PosterHomeScreen(user: _user, onRefresh: _load)
                : SeekerHomeScreen(user: _user, onRefresh: _load),
            const ActiveJobScreen(),
            NotificationsScreen(notifs: _notifs),
            _profileTab(),
          ],
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    if (_isPoster) {
      return Stack(clipBehavior: Clip.none, children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
          decoration: BoxDecoration(
            color: kBlack,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 10, left: 16, right: 16, bottom: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(0, Icons.home_rounded, 'Home'),
                      _navItem(1, Icons.shopping_bag_rounded, 'Active'),
                      const SizedBox(width: 52),
                      _navBadge(
                          2, Icons.notifications_rounded, _notifs.unreadCount),
                      _navItem(3, Icons.person_rounded, 'Profile'),
                    ]),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 36,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/post-job'),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F77E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFF9F77E).withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: kBlack, size: 30),
              ),
            ),
          ),
        ),
      ]);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.home_rounded, 'Home'),
                  _navItem(1, Icons.shopping_bag_rounded, 'Active'),
                  _navBadge(
                      2, Icons.notifications_rounded, _notifs.unreadCount),
                  _navItem(3, Icons.person_rounded, 'Profile'),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: active ? const Color(0xFFF9F77E) : Colors.white54,
              size: 26),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                  color: Color(0xFFF9F77E), shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  Widget _navBadge(int idx, IconData icon, int count) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Stack(clipBehavior: Clip.none, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: active ? const Color(0xFFF9F77E) : Colors.white54,
                size: 26),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: Color(0xFFF9F77E), shape: BoxShape.circle),
              ),
          ]),
        ),
        if (count > 0)
          Positioned(
            top: 0,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Color(0xFFF9F77E), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              child: Text(count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: kBlack, fontSize: 9, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
            ),
          ),
      ]),
    );
  }

  Widget _profileTab() {
    final initial = (_user?['fullName'] as String? ?? 'A')[0].toUpperCase();
    final role = _user?['activeRole']?.toString() ?? 'worker';
    final isPoster = role == 'employer';
    final wRating = (_user?['workerRating'] as num?)?.toDouble() ?? 0;
    final eRating = (_user?['employerRating'] as num?)?.toDouble() ?? 0;
    final wCount = (_user?['workerRatingCount'] as num?)?.toInt() ?? 0;
    final eCount = (_user?['employerRatingCount'] as num?)?.toInt() ?? 0;
    final area = _user?['area'] as String? ?? '';
    final city = _user?['city'] as String? ?? '';
    final location = area.isNotEmpty && city.isNotEmpty ? '$area, $city' : city;

    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 260,
        pinned: true,
        backgroundColor: kBlack,
        automaticallyImplyLeading: false,
        title: const Text('Profile',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined, color: kWhite, size: 20),
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()))
                  .then((_) => _load())),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
            ),
            Positioned(
                top: -30,
                right: -30,
                child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFFF9F77E).withValues(alpha: 0.06)))),
            Positioned(
                bottom: 0,
                left: -20,
                child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kPurple.withValues(alpha: 0.08)))),
            Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF9F77E), Color(0xFFE8E660)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFF9F77E)
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Center(
                          child: Text(initial,
                              style: const TextStyle(
                                  color: kBlack,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900))),
                    ),
                    const SizedBox(height: 12),
                    Text(_user?['fullName'] ?? '',
                        style: const TextStyle(
                            color: kWhite,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    buildTag(isPoster ? 'EMPLOYER' : 'WORKER',
                        isPoster ? kPurple : const Color(0xFFF9F77E)),
                  ]),
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Switch role card
            GestureDetector(
              onTap: _switching ? null : _switchRole,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isPoster
                      ? const LinearGradient(colors: [kPurple, kPurpleLight])
                      : const LinearGradient(
                          colors: [Color(0xFFF9F77E), Color(0xFFE8E660)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: kShadow,
                ),
                child: Row(children: [
                  Icon(
                      isPoster
                          ? Icons.build_rounded
                          : Icons.business_center_rounded,
                      color: isPoster ? kWhite : kBlack),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Currently: ${isPoster ? "Employer" : "Worker"}',
                            style: TextStyle(
                                color: isPoster ? kWhite : kBlack,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        Text(
                            'Tap to switch to ${isPoster ? "Worker" : "Employer"} mode',
                            style: TextStyle(
                                color: isPoster
                                    ? kWhite.withValues(alpha: 0.7)
                                    : kBlack.withValues(alpha: 0.6),
                                fontSize: 11)),
                      ])),
                  _switching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: isPoster ? kWhite : kBlack,
                              strokeWidth: 2))
                      : Icon(Icons.swap_horiz_rounded,
                          color: isPoster ? kWhite : kBlack),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Ratings row
            Row(children: [
              Expanded(child: _ratingCard('As Worker', wRating, wCount)),
              const SizedBox(width: 12),
              Expanded(child: _ratingCard('As Employer', eRating, eCount)),
            ]),
            const SizedBox(height: 20),
            ACard(
                child: Column(children: [
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Personal Info',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: kBlack))),
              const SizedBox(height: 16),
              _infoRow(Icons.phone_rounded, 'Phone',
                  _user?['phoneNumber'] ?? '—', kBlue),
              Divider(height: 24, color: kDivider),
              _infoRow(Icons.location_on_rounded, 'Location',
                  location.isNotEmpty ? location : 'Not set', kPurple),
              Divider(height: 24, color: kDivider),
              _infoRow(Icons.flag_rounded, 'Country',
                  _user?['country'] ?? 'Not set', kGreen),
            ])),
            const SizedBox(height: 20),
            // Settings button
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                          user: _user, onLogout: _logout, onRefresh: _load))),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: kShadow),
                child: Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: kGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.settings_rounded,
                          color: kGrey, size: 20)),
                  const SizedBox(width: 14),
                  const Text('Settings',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: kBlack)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: kGrey),
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    ]);
  }

  Widget _ratingCard(String label, double rating, int count) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: kShadow),
        child: Column(children: [
          Text(rating > 0 ? rating.toStringAsFixed(1) : '—',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: kBlack)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade600),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(color: kGrey, fontSize: 11)),
          ]),
          Text('$count reviews',
              style: const TextStyle(color: kGrey, fontSize: 10)),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value, Color color) =>
      Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: kGrey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: kBlack)),
      ]);
}
