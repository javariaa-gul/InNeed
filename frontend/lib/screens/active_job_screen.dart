import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';

class ActiveJobScreen extends StatefulWidget {
  const ActiveJobScreen({super.key});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  bool _updating = false;
  Map<String, dynamic>? _job;
  String _role = 'worker';
  String? _userId;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // Activity stages
  static const _stages = ['accepted', 'started', 'in_progress', 'completed'];
  static const _stageLabels = ['Accepted', 'Started', 'In Progress', 'Completed'];
  static const _stageIcons = [
    Icons.handshake_rounded,
    Icons.play_circle_rounded,
    Icons.construction_rounded,
    Icons.check_circle_rounded,
  ];

  int get _currentStageIdx {
    final status = _job?['status']?.toString() ?? 'accepted';
    final idx = _stages.indexOf(status);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadActiveJob();
    _setupSocket();
  }

  void _setupSocket() {
    SocketService().on('job_status_updated', (d) {
      if (!mounted) return;
      final jobId = d['jobId'] as int?;
      if (jobId != null && _job?['id'] == jobId) {
        setState(() => _job?['status'] = d['status']);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SocketService().off('job_status_updated');
    super.dispose();
  }

  Future<void> _loadActiveJob() async {
    try {
      if (mounted) setState(() => _loading = true);
      final user = await _api.getMe();
      _role = user['activeRole']?.toString() ?? await StorageService.getActiveRole();
      _userId = await StorageService.getUserId();

      if (_role == 'worker') {
        _job = await _api.getActiveJob();
      } else {
        final jobs = await _api.getMyJobs();
        final active = jobs.cast<Map<String, dynamic>>().where((j) {
          final s = (j['status'] as String?)?.toLowerCase() ?? '';
          return s == 'active' || s == 'accepted' || s == 'started' ||
              s == 'in_progress' || j['acceptedSeekerId'] != null;
        }).toList();
        _job = active.isEmpty ? null : active.first;
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? get _currentUserId => int.tryParse(_userId ?? '');
  bool get _isSeeker => _role == 'worker';

  int? get _revieweeId {
    if (_job == null || _currentUserId == null) return null;
    final posterId = _job!['posterId'] as int?;
    final seekerId = _job!['acceptedSeekerId'] as int?;
    if (posterId == null || seekerId == null) return null;
    return _currentUserId == posterId ? seekerId : posterId;
  }

  String get _otherLabel => _isSeeker ? 'Poster' : 'Worker';

  Future<void> _advanceStatus() async {
    if (_job == null || _updating) return;
    final nextIdx = _currentStageIdx + 1;
    if (nextIdx >= _stages.length) return;

    final nextStatus = _stages[nextIdx];

    // If advancing to completed, confirm first
    if (nextStatus == 'completed') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Mark as Completed?',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
              'This will trigger the mandatory review process for both parties.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen, foregroundColor: kWhite),
              child: const Text('Yes, Complete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _updating = true);
    try {
      if (nextStatus == 'completed') {
        await _api.completeJob(_job!['id'] as int);
        if (_revieweeId != null && mounted) {
          Navigator.pushReplacementNamed(context, '/review', arguments: {
            'jobId': _job!['id'],
            'revieweeId': _revieweeId,
            'revieweeName': _otherLabel,
          });
        }
        return;
      } else {
        await _api.updateJobStatus(_job!['id'] as int, nextStatus);
        setState(() => _job?['status'] = nextStatus);
        showSnack(context, 'Status updated to ${_stageLabels[nextIdx]}!', ok: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: kBg,
          body: Center(child: CircularProgressIndicator(color: kBlack)));
    }

    return Scaffold(
      backgroundColor: kBg,
      body: _job == null ? _emptyState() : _jobContent(),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    color: kBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: kDivider, width: 2)),
                child: const Icon(Icons.work_off_rounded, size: 42, color: kGrey),
              ),
            ),
            const SizedBox(height: 24),
            const Text('No Active Job',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20, color: kBlack)),
            const SizedBox(height: 10),
            const Text(
              'Once a job is accepted on both sides, it appears here with a progress tracker.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kGrey, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _loadActiveJob,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: kBlack, borderRadius: BorderRadius.circular(14)),
                child: const Text('Refresh',
                    style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );

  Widget _jobContent() {
    final job = _job!;
    final stageIdx = _currentStageIdx;
    final canAdvance = _isSeeker && stageIdx < _stages.length - 1;

    return RefreshIndicator(
      onRefresh: _loadActiveJob,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 10),
          // Job card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kBlack,
              borderRadius: BorderRadius.circular(24),
              boxShadow: kShadow,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: kGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('ACTIVE',
                        style: TextStyle(
                            color: kGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                const Spacer(),
                Text('ID #${job['id']}',
                    style: const TextStyle(color: kGrey, fontSize: 11)),
              ]),
              const SizedBox(height: 14),
              Text(job['title'] as String? ?? 'Untitled',
                  style: const TextStyle(
                      color: kWhite, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(job['description'] as String? ?? '',
                  style: TextStyle(
                      color: kWhite.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Row(children: [
                _jobChip(Icons.monetization_on_rounded,
                    'Rs. ${(job['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    kGreen),
                const SizedBox(width: 10),
                _jobChip(
                    Icons.flag_rounded,
                    (job['urgency'] as String? ?? 'flexible').toUpperCase(),
                    kOrange),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          // Activity progress bar
          const Text('Job Progress',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kBlack)),
          const SizedBox(height: 14),
          _activityBar(stageIdx),
          const SizedBox(height: 24),
          // Advance button (seeker only)
          if (canAdvance) ...[
            _isSeeker
                ? GestureDetector(
                    onTap: _updating ? null : _advanceStatus,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: stageIdx + 1 == _stages.length - 1
                              ? [kGreen, const Color(0xFF27AE60)]
                              : [kBlack, const Color(0xFF2D2D2D)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: kShadow,
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_updating)
                              const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: kWhite, strokeWidth: 2))
                            else ...[
                              Icon(
                                _stageIcons[(stageIdx + 1)
                                    .clamp(0, _stages.length - 1)],
                                color: kWhite,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                stageIdx + 1 == _stages.length - 1
                                    ? 'Mark as Completed'
                                    : 'Mark as ${_stageLabels[(stageIdx + 1).clamp(0, _stages.length - 1)]}',
                                style: const TextStyle(
                                    color: kWhite,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15),
                              ),
                            ],
                          ]),
                    ),
                  )
                : Container(),
            const SizedBox(height: 16),
          ],
          // Chat button
          GestureDetector(
            onTap: () {
              if (_revieweeId != null) {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'jobId': job['id'],
                  'otherUserId': _revieweeId,
                  'otherName': _otherLabel,
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: kShadow,
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F77E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFFF9F77E), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text('Chat with $_otherLabel',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: kBlack)),
                  const Text('Coordinate and stay in touch',
                      style: TextStyle(color: kGrey, fontSize: 11)),
                ])),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: kGrey),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _jobChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _activityBar(int currentIdx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kShadow),
      child: Column(children: [
        // Progress indicator line
        Row(children: List.generate(_stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final lineIdx = i ~/ 2;
            final filled = lineIdx < currentIdx;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 3,
                color: filled ? kGreen : kDivider,
              ),
            );
          } else {
            // Stage dot
            final stageIdx = i ~/ 2;
            final done = stageIdx <= currentIdx;
            final active = stageIdx == currentIdx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 36 : 28,
              height: active ? 36 : 28,
              decoration: BoxDecoration(
                color: done ? kGreen : kDivider,
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: kGreen.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Icon(
                done ? _stageIcons[stageIdx] : _stageIcons[stageIdx],
                color: done ? kWhite : kGrey,
                size: active ? 18 : 13,
              ),
            );
          }
        })),
        const SizedBox(height: 10),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_stages.length, (i) {
            final done = i <= currentIdx;
            final active = i == currentIdx;
            return Expanded(
              child: Text(
                _stageLabels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? kBlack : (done ? kGreen : kGrey),
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
        if (_isSeeker) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F77E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Color(0xFFF9F77E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'You (seeker) control the progress. Tap the button above to advance the status.',
                  style: TextStyle(
                      color: kBlack, fontSize: 10, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
