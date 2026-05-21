import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'bids_screen.dart';

// Pastel color palette for job cards
const List<Color> kPastelColors = [
  Color(0xFFFFD6E8), // Pastel pink
  Color(0xFFC7CEEA), // Pastel purple
  Color(0xFFB5EAD7), // Pastel mint
  Color(0xFFFFFCC7), // Pastel yellow
  Color(0xFFFFCCB4), // Pastel peach
  Color(0xFFE0BBE4), // Pastel lavender
  Color(0xFFD4F1F4), // Pastel cyan
  Color(0xFFF8B4D6), // Pastel magenta
];

class PosterHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onRefresh;

  const PosterHomeScreen(
      {super.key, required this.user, required this.onRefresh});

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
    final location = area.isNotEmpty && city.isNotEmpty ? '$area, $city' : city;

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
                padding: const EdgeInsets.fromLTRB(18, 38, 18, 10),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: kShadow,
                      border: Border.all(
                          color: kPrimaryLime.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hi, $fullName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kBlack,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.location_on_rounded,
                                  color: kGrey, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location.isNotEmpty
                                      ? location
                                      : 'Location not set',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: kGrey, fontSize: 13),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                    ]),
                  ),
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
                  _statBox('Live', _liveCount.toString(), Icons.circle, kGreen,
                      'Active posts'),
                  const SizedBox(width: 12),
                  _statBox('Offers', _offersCount.toString(),
                      Icons.swap_horiz_rounded, kOrange, 'Counter offers'),
                  const SizedBox(width: 12),
                  _statBox('Total', _totalCount.toString(), Icons.work_rounded,
                      kPurple, 'All posts'),
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
                            color: const Color(0xFFF9F77E),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$_liveCount active',
                            style: const TextStyle(
                                color: kBlack,
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

  Widget _statBox(
      String label, String val, IconData icon, Color color, String sub) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F77E),
          borderRadius: BorderRadius.circular(18),
          boxShadow: kShadow,
          border: Border.all(color: kBlack, width: 1.6),
        ),
        child: Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFF9F77E),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kBlack, size: 22),
          ),
          const SizedBox(height: 8),
          Text(val,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: kBlack)),
          Text(label,
              style: const TextStyle(
                  color: kBlack, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> job) {
    final title = job['title'] as String? ?? 'Untitled';
    final description = (job['description'] as String?) ??
        (job['details'] as String?) ??
        (job['summary'] as String?) ??
        'No description provided.';
    final price = (job['price'] as num?)?.toDouble() ?? 0;
    final bids = (job['bids'] as List<dynamic>?) ?? [];
    final exp = job['expiresAt'] != null
        ? DateTime.tryParse(job['expiresAt'].toString())
        : null;
    final remaining = exp != null ? exp.difference(DateTime.now()) : null;

    // Poster information
    final poster = job['poster'] as Map<String, dynamic>? ?? {};
    final posterName = poster['fullName'] as String? ?? 'Unknown';
    final posterCity = poster['city'] as String? ?? '';
    final posterArea = poster['area'] as String? ?? '';
    final posterLocation =
        [posterArea, posterCity].where((e) => e.isNotEmpty).join(', ');
    final posterPic = (poster['profilePicUrl'] as String?)?.isEmpty == false
        ? poster['profilePicUrl'] as String?
        : null;
    final posterRating = (poster['employerRating'] as num?)?.toDouble() ?? 0;
    final posterRatingCount =
        (poster['employerRatingCount'] as num?)?.toInt() ?? 0;

    // Get deterministic pastel color based on job id
    final cardColor =
        kPastelColors[(job['id'] as int? ?? 0) % kPastelColors.length];
    final isDark = _isColorDark(cardColor);
    final textColor = isDark ? kWhite : kBlack;

    // Status badge based on rating
    final statusBadge = _getStatusBadge(posterRating);

    return _SwipeableJobCard(
      onSwipeRight: () {
        // Right swipe: Accept and open bids
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BidsScreen(jobId: job['id'] as int),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster info header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Poster avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark
                        ? kWhite.withValues(alpha: 0.15)
                        : kBlack.withValues(alpha: 0.1),
                    backgroundImage:
                        posterPic != null ? NetworkImage(posterPic) : null,
                    child: posterPic == null
                        ? Text(
                            posterName[0].toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Poster details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          posterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: textColor.withValues(alpha: 0.6),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                posterLocation.isNotEmpty
                                    ? posterLocation
                                    : 'Location not set',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Rating and reviews
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB800),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$posterRating',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($posterRatingCount reviews)',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadge['color'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusBadge['icon'] as IconData,
                          color: kBlack,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusBadge['label'] as String,
                          style: const TextStyle(
                            color: kBlack,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Job title and price
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (bids.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFF9F77E)
                                : kBlack.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${bids.length} offers',
                            style: TextStyle(
                              color: isDark ? kBlack : textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        color: isDark ? const Color(0xFF333333) : kBlack,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rs. ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (remaining != null && remaining.isNegative == false)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatRemaining(remaining),
                            style: const TextStyle(
                              color: kRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Description
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? kBlack.withValues(alpha: 0.06)
                    : kBlack.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Footer with swipe hints
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? kBlack.withValues(alpha: 0.04)
                    : kBlack.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: textColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: textColor.withValues(alpha: 0.5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swipe right to view offers →',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to determine if color is dark
  bool _isColorDark(Color color) {
    final luminance = color.computeLuminance();
    return luminance < 0.5;
  }

  // Get status badge based on rating
  Map<String, dynamic> _getStatusBadge(double rating) {
    if (rating >= 4.8) {
      return {
        'label': 'PRO',
        'color': const Color(0xFF4CAF50),
        'icon': Icons.verified_rounded,
      };
    } else if (rating >= 4.5) {
      return {
        'label': 'TRUSTED',
        'color': const Color(0xFF2196F3),
        'icon': Icons.shield_rounded,
      };
    } else if (rating >= 4.0) {
      return {
        'label': 'GOOD',
        'color': const Color(0xFFFFB800),
        'icon': Icons.thumb_up_rounded,
      };
    } else {
      return {
        'label': 'NEW',
        'color': const Color(0xFFE0E0E0),
        'icon': Icons.star_rounded,
      };
    }
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
            onTap: () {
              Navigator.pushNamed(context, '/post-job');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

// Swipeable card widget for job cards
class _SwipeableJobCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight;

  const _SwipeableJobCard({
    required this.child,
    required this.onSwipeRight,
  });

  @override
  State<_SwipeableJobCard> createState() => _SwipeableJobCardState();
}

class _SwipeableJobCardState extends State<_SwipeableJobCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    const swipeThreshold = 0.15; // 15% of screen width

    if (_dragOffset > screenWidth * swipeThreshold) {
      // Swiped right
      widget.onSwipeRight();
      // Animate off screen
      _animationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _isDragging = false;
          });
          _animationController.reset();
        }
      });
    } else {
      // Not enough drag, snap back
      _animationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _isDragging = false;
          });
          _animationController.reset();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Opacity(
        opacity: (1 - (_dragOffset.abs() / 300)).clamp(0, 1),
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _dragOffset > 0
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Background swipe indicator
                if (_isDragging && _dragOffset > 0)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF4CAF50),
                        size: 40,
                      ),
                    ),
                  ),
                // Main card
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
