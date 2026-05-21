import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

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

class JobFeedScreen extends StatefulWidget {
  const JobFeedScreen({super.key});
  @override
  State<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends State<JobFeedScreen> {
  final _api = ApiService();
  List<JobModel> _jobs = [];
  bool _loading = true;
  int _idx = 0; // current card index

  @override
  void initState() {
    super.initState();
    _load();
    _listenSocket();
  }

  void _listenSocket() {
    SocketService().on('new_job_card', (d) {
      try {
        final job = JobModel.fromJson(d);
        if (mounted) setState(() => _jobs.insert(0, job));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    SocketService().off('new_job_card');
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final raw = await _api.getJobFeed();
      if (mounted) {
        setState(() {
          _jobs = raw.map((j) => JobModel.fromJson(j)).toList();
          _idx = 0;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    if (_idx >= _jobs.length) return;
    final job = _jobs[_idx];
    try {
      await _api.rejectJob(job.id);
    } catch (_) {}
    setState(() => _idx++);
  }

  Color _getJobCardColor(int index) {
    return kPastelColors[index % kPastelColors.length];
  }

  void _showBidSheet(JobModel job) {
    final priceCtrl = TextEditingController(text: job.price.toStringAsFixed(0));
    final msgCtrl = TextEditingController();
    bool submitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setBS) => Container(
                margin: const EdgeInsets.all(16),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    left: 20,
                    right: 20,
                    top: 20),
                decoration: BoxDecoration(
                    color: kWhite, borderRadius: BorderRadius.circular(24)),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: kDivider,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text('Counter Offer',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: kBlack)),
                      const SizedBox(height: 4),
                      Text(
                          'Original: Rs. ${job.price.toStringAsFixed(0)} ${job.pricingType == "hourly" ? "/ hr" : "fixed"}',
                          style: const TextStyle(color: kGrey, fontSize: 13)),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Your Price (Rs.)',
                              prefixIcon: Icon(Icons.money_rounded))),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: msgCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Message (optional)',
                              prefixIcon: Icon(Icons.message_outlined))),
                      const SizedBox(height: 20),
                      GradBtn(
                        text: submitting ? 'Sending…' : 'SEND BID',
                        loading: submitting,
                        gradient: kBlueGrad,
                        foreColor: kWhite,
                        onTap: () async {
                          final price = double.tryParse(priceCtrl.text);
                          if (price == null || price <= 0) {
                            showSnack(context, 'Enter valid price', err: true);
                            return;
                          }
                          setBS(() => submitting = true);
                          try {
                            await _api.placeBid(job.id, price,
                                message: msgCtrl.text.trim().isEmpty
                                    ? null
                                    : msgCtrl.text.trim());
                            if (mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted && context.mounted) {
                              showSnack(
                                  context, 'Bid sent! Waiting for poster.',
                                  ok: true);
                              setState(() => _idx++);
                            }
                          } catch (e) {
                            if (mounted) {
                              showSnack(context, e.toString(), err: true);
                            }
                          } finally {
                            setBS(() => submitting = false);
                          }
                        },
                      ),
                    ]),
              )),
    );
  }

  bool _isColorDark(Color color) {
    final luminance = color.computeLuminance();
    return luminance < 0.5;
  }

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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          title: const Text('Job Cards'),
          leading: const BackButton(color: kWhite),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded, color: kWhite),
                onPressed: _load)
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : _idx >= _jobs.length
                ? _emptyState()
                : Column(children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(children: [
                          Text('${_jobs.length - _idx} jobs for you',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: kGrey)),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: kBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('Swipe right to bid',
                                  style: TextStyle(
                                      color: kBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                        ])),
                    Expanded(child: _cardStack()),
                    _actionButtons(),
                  ]),
      );

  Widget _cardStack() {
    final visible = <Widget>[];
    for (int i = (_idx + 2).clamp(0, _jobs.length - 1); i >= _idx; i--) {
      final offset = i - _idx;
      final color = _getJobCardColor(i);
      visible.add(Positioned(
        top: offset * 8.0,
        left: offset * 6.0,
        right: offset * 6.0,
        child: _jobCard(_jobs[i], color, isTop: i == _idx),
      ));
    }
    return Stack(alignment: Alignment.center, children: visible);
  }

  Widget _jobCard(JobModel job, Color color, {required bool isTop}) {
    final isDark = _isColorDark(color);
    final textColor = isDark ? kWhite : kBlack;

    // Extract poster information
    final poster = job.poster ?? {};
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

    // Get status badge based on rating
    final statusBadge = _getStatusBadge(posterRating);

    return _SwipeableJobCard(
      onSwipeRight: () => _showBidSheet(job),
      onSwipeLeft: () => _reject(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: MediaQuery.of(context).size.height * 0.48,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(children: [
          // Poster info header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // Poster avatar
                CircleAvatar(
                  radius: 22,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: textColor.withValues(alpha: 0.6),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              posterLocation.isNotEmpty
                                  ? posterLocation
                                  : 'Location not set',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            posterRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($posterRatingCount)',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBadge['color'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusBadge['icon'] as IconData,
                        color: kBlack,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        statusBadge['label'] as String,
                        style: const TextStyle(
                          color: kBlack,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Job content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(job.urgency.toUpperCase(),
                            style: TextStyle(
                                color: textColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800))),
                    const Spacer(),
                    if (job.skillRequired != null)
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16)),
                          child: Text(job.skillRequired!,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 10),
                  Text(job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.1)),
                  const SizedBox(height: 8),
                  Text(job.description,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  // Price
                  Row(children: [
                    Icon(Icons.monetization_on_rounded,
                        color: textColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                        'Rs. ${job.price.toStringAsFixed(0)}${job.pricingType == "hourly" ? " / hr" : " fixed"}',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ]),
                  const SizedBox(height: 4),
                  // Location
                  Row(children: [
                    Icon(
                        job.isRemote
                            ? Icons.wifi_rounded
                            : Icons.location_on_rounded,
                        color: textColor.withValues(alpha: 0.7),
                        size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                            job.isRemote
                                ? 'Remote'
                                : (job.locationAddress ?? 'On-site'),
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionButtons() => SafeArea(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _actionBtn(Icons.close_rounded, kRed, 'Skip', _reject),
            _actionBtn(Icons.check_rounded, kGreen, 'Bid',
                () => _showBidSheet(_jobs[_idx]),
                large: true),
          ])));

  Widget _actionBtn(
      IconData icon, Color color, String label, VoidCallback onTap,
      {bool large = false}) {
    final size = large ? 70.0 : 56.0;
    return GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kWhite,
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]),
              child: Icon(icon, color: color, size: large ? 34 : 26)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]));
  }

  Widget _emptyState() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBg,
                border: Border.all(color: kDivider, width: 2)),
            child: const Icon(Icons.style_rounded, size: 44, color: kGrey)),
        const SizedBox(height: 20),
        const Text('No More Jobs',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 20, color: kBlack)),
        const SizedBox(height: 8),
        const Text('Check back soon for new opportunities.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kGrey, fontSize: 13)),
        const SizedBox(height: 24),
        GestureDetector(
            onTap: _load,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    gradient: kBlueGrad,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('Refresh',
                    style: TextStyle(
                        color: kWhite, fontWeight: FontWeight.w800)))),
      ]));
}

// Swipeable card widget
class _SwipeableJobCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;

  const _SwipeableJobCard({
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
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

    if (_dragOffset.abs() > screenWidth * swipeThreshold) {
      if (_dragOffset > 0) {
        // Swiped right
        widget.onSwipeRight();
      } else {
        // Swiped left
        widget.onSwipeLeft();
      }
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
                    : kRed.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Background swipe indicator
                if (_isDragging)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _dragOffset > 0
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF4CAF50),
                              size: 40,
                            )
                          : null,
                    ),
                  ),
                if (_isDragging)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _dragOffset < 0
                          ? const Icon(
                              Icons.close_rounded,
                              color: kRed,
                              size: 40,
                            )
                          : null,
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
