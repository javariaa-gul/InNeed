import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/app_theme.dart';

class BidModel {
  final int id;
  final int jobId;
  final int seekerId;
  final double offeredPrice;
  final String? message;
  final String status;
  final Map<String, dynamic>? seeker;
  final bool isCounterOffer;
  final double? previousPrice;

  BidModel({
    required this.id,
    required this.jobId,
    required this.seekerId,
    required this.offeredPrice,
    this.message,
    required this.status,
    this.seeker,
    this.isCounterOffer = false,
    this.previousPrice,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: json['id'],
      jobId: json['jobId'],
      seekerId: json['seekerId'],
      offeredPrice: (json['offeredPrice'] as num).toDouble(),
      message: json['message'],
      status: json['status'],
      seeker: json['seeker'],
      isCounterOffer: json['isCounterOffer'] ?? false,
      previousPrice: json['previousPrice'] != null
          ? (json['previousPrice'] as num).toDouble()
          : null,
    );
  }
}

class BidsScreen extends StatefulWidget {
  final int jobId;
  const BidsScreen({super.key, required this.jobId});

  @override
  State<BidsScreen> createState() => _BidsScreenState();
}

class _BidsScreenState extends State<BidsScreen> {
  final _api = ApiService();
  List<BidModel> _bids = [];
  Map<String, dynamic>? _job;
  bool _loading = true;
  int? _accepting;

  @override
  void initState() {
    super.initState();
    _load();
    SocketService().on('new_bid', _handleNewBidEvent);
    SocketService().on('bid_updated', _handleBidUpdatedEvent);
  }

  @override
  void dispose() {
    SocketService().off('new_bid');
    SocketService().off('bid_updated');
    super.dispose();
  }

  void _handleNewBidEvent(Map<String, dynamic> data) {
    final eventJobId = data['jobId'];
    if (eventJobId == widget.jobId && mounted) {
      showSnack(context, 'New bid received! Refreshing...', ok: true);
      _load();
    }
  }

  void _handleBidUpdatedEvent(Map<String, dynamic> data) {
    final eventJobId = data['jobId'];
    if (eventJobId == widget.jobId && mounted) {
      showSnack(context, 'Counter offer received. Check updated price.',
          ok: true);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final results = await Future.wait([
        _api.getJob(widget.jobId),
        _api.getBidsForJob(widget.jobId),
      ]);
      if (mounted) {
        setState(() {
          _job = results[0] as Map<String, dynamic>;
          _bids =
              (results[1] as List).map((b) => BidModel.fromJson(b)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString(), err: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(BidModel bid) async {
    setState(() => _accepting = bid.id);
    try {
      await _api.acceptBid(widget.jobId, bid.id);
      if (mounted) {
        showSnack(context, 'Bid accepted! Job is now ACTIVE ✓', ok: true);
        Navigator.pushReplacementNamed(context, '/active-job');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          title: Text('Bids (${_bids.length})'),
          leading: const BackButton(color: kWhite),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: kWhite),
              onPressed: _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kBlack))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    if (_job != null) _jobHeader(),
                    if (_job != null) _jobDetails(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bids (${_bids.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: kBlack,
                          ),
                        ),
                      ),
                    ),
                    if (_bids.isEmpty)
                      _emptyState()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bids.length,
                          itemBuilder: (_, i) => _bidCard(_bids[i]),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      );

  Widget _jobHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kShadow,
          border: Border.all(color: const Color(0xFFFEFD99), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _job!['title'] ?? 'Untitled Job',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFD99),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs. ${(_job!['price'] as num?)?.toStringAsFixed(0) ?? '0'} ${_job!['pricingType'] == 'hourly' ? '/ hr' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: kBlack,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    (_job!['status'] ?? 'open').toString().toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: kGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _jobDetails() {
    final poster = _job?['poster'] as Map<String, dynamic>? ?? {};
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
    final description = (_job!['description'] as String?) ??
        (_job!['details'] as String?) ??
        'No description provided.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Poster info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFEFD99), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFEFD99),
                  backgroundImage:
                      posterPic != null ? NetworkImage(posterPic) : null,
                  child: posterPic == null
                      ? Text(
                          posterName[0].toUpperCase(),
                          style: const TextStyle(
                            color: kBlack,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        posterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: kBlack,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: kGrey,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              posterLocation.isNotEmpty
                                  ? posterLocation
                                  : 'Location not set',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kGrey,
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
                            size: 12,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            posterRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: kBlack,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '($posterRatingCount)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: kGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Job description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFD99).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFEFD99),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: kBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bidCard(BidModel bid) {
    final seeker = bid.seeker ?? {};
    final name = (seeker['fullName'] as String?) ?? 'Worker';
    final rating = (seeker['workerRating'] as num?)?.toDouble() ?? 0;
    final initial = name[0].toUpperCase();
    final isCounterOffer = bid.isCounterOffer ||
        (bid.previousPrice != null && bid.previousPrice != bid.offeredPrice);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kShadow,
        border: Border.all(color: const Color(0xFFFEFD99), width: 1.3),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFFEFD99),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: kBlack,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: kBlack,
                            ),
                          ),
                          if (isCounterOffer) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kBlue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'COUNTER',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: kBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: kBlack,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (bid.previousPrice != null &&
                        bid.previousPrice != bid.offeredPrice)
                      Text(
                        'Rs. ${bid.previousPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: kGrey,
                          fontSize: 10,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEFD99),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFEFD99),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Rs. ${bid.offeredPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: kBlack,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (bid.message?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFD99).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFEFD99).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  bid.message!,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: GradBtn(
              text: 'ACCEPT — Rs. ${bid.offeredPrice.toStringAsFixed(0)}',
              gradient: kGreenGrad,
              foreColor: kWhite,
              onTap: _accepting == bid.id ? () {} : () => _accept(bid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: kBlack),
            const SizedBox(height: 16),
            const Text(
              'No Bids Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Workers will see your job card soon.',
              style: TextStyle(color: kBlack, fontSize: 13),
            ),
          ],
        ),
      );
}
