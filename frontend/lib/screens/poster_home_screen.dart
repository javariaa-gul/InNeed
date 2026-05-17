import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'bids_screen.dart';

class PosterHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onRefresh;

  const PosterHomeScreen({super.key, required this.user, required this.onRefresh});

  @override
  State<PosterHomeScreen> createState() => _PosterHomeScreenState();
}

class _PosterHomeScreenState extends State<PosterHomeScreen> {
  final _api = ApiService();
  List<dynamic> _livePosts = [];
  bool _loadingPosts = true;
  int _liveCount = 0, _offersCount = 0, _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loadingPosts = true);
      final jobs = await _api.getMyJobs();
      final now = DateTime.now();
      final live = jobs.cast<Map<String, dynamic>>().where((j) {
        final exp = j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'].toString())
            : null;
        final status = j['status']?.toString().toLowerCase() ?? '';
        return status != 'expired' &&
            status != 'completed' &&
            (exp == null || exp.isAfter(now));
      }).toList();

      int offers = 0;
      for (final job in live) {
        final bids = job['bids'] as List<dynamic>? ?? [];
        offers += bids.length;
      }

      if (mounted) {
        setState(() {
          _livePosts = live;
          _liveCount = live.length;
          _offersCount = offers;
          _totalCount = jobs.length;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final fullName = user?['fullName'] as String? ?? '';
    final area = user?['area'] as String? ?? '';
    final city = user?['city'] as String? ?? '';
    final location =
        area.isNotEmpty && city.isNotEmpty ? '$area, $city' : city;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        widget.onRefresh();
      },
      color: kBlack,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Top header
          SliverAppBar(
            pinned: true,
            backgroundColor: kWhite,
            elevation: 0,
            automaticallyImplyLeading: false,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: kWhite,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hi, $fullName',
                            style: const TextStyle(
                                color: kBlack,
                                fontSize: 22,
                                fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_rounded,
                                color: kGrey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              location.isNotEmpty ? location : 'Location not set',
                              style: const TextStyle(color: kGrey, fontSize: 13),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F77E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Employer',
                          style: TextStyle(
                              color: kBlack,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Stats boxes
                Row(children: [
                  _statBox('Live', _liveCount.toString(),
                      Icons.circle, kGreen, 'Active posts'),
                  const SizedBox(width: 12),
                  _statBox('Offers', _offersCount.toString(),
                      Icons.swap_horiz_rounded, kOrange, 'Counter offers'),
                  const SizedBox(width: 12),
                  _statBox('Total', _totalCount.toString(),
                      Icons.work_rounded, kPurple, 'All posts'),
                ]),
                const SizedBox(height: 28),
                // Live posts section
                Row(children: [
                  const Text('Your Live Posts',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kBlack)),
                  const Spacer(),
                  if (_liveCount > 0)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: kGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$_liveCount active',
                            style: const TextStyle(
                                color: kGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 14),
                if (_loadingPosts)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: kBlack))
                else if (_livePosts.isEmpty)
                  _emptyState()
                else
                  ..._livePosts
                      .map((job) => _postCard(job as Map<String, dynamic>))
                      .toList(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String val, IconData icon, Color color, String sub) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(18),
          boxShadow: kShadow,
        ),
        child: Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(val,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: kBlack)),
          Text(label,
              style: const TextStyle(color: kGrey, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> job) {
    final title = job['title'] as String? ?? 'Untitled';
    final price = (job['price'] as num?)?.toDouble() ?? 0;
    final bids = (job['bids'] as List<dynamic>?) ?? [];
    final status = job['status'] as String? ?? '';
    final exp = job['expiresAt'] != null
        ? DateTime.tryParse(job['expiresAt'].toString())
        : null;
    final remaining = exp != null ? exp.difference(DateTime.now()) : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BidsScreen(jobId: job['id'] as int)),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kShadow,
          border: Border.all(
              color: bids.isNotEmpty
                  ? kOrange.withValues(alpha: 0.3)
                  : kDivider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: kBlack)),
            ),
            if (bids.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.notifications_rounded,
                      color: kOrange, size: 13),
                  const SizedBox(width: 4),
                  Text('${bids.length} offers',
                      style: const TextStyle(
                          color: kOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.monetization_on_rounded, color: kGrey, size: 14),
            const SizedBox(width: 4),
            Text('Rs. ${price.toStringAsFixed(0)}',
                style: const TextStyle(color: kGrey, fontSize: 12)),
            const Spacer(),
            if (remaining != null && remaining.isNegative == false)
              Text(
                _formatRemaining(remaining),
                style: TextStyle(
                    color: remaining.inHours < 1 ? kRed : kGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('LIVE',
                  style: const TextStyle(
                      color: kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            const Text('Tap to see offers →',
                style: TextStyle(
                    color: kGrey, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h left';
    return '${d.inMinutes}m left';
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: kBg,
                shape: BoxShape.circle,
                border: Border.all(color: kDivider, width: 2)),
            child: const Icon(Icons.work_off_rounded, size: 38, color: kGrey),
          ),
          const SizedBox(height: 16),
          const Text('No Live Posts',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: kBlack)),
          const SizedBox(height: 8),
          const Text('Post a job to start hiring workers.',
              style: TextStyle(color: kGrey, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/post-job'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF9F77E),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Post a Job',
                  style: TextStyle(color: kBlack, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}
