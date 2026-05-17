import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class SeekerHomeScreen extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onRefresh;

  const SeekerHomeScreen({super.key, required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final fullName = user?['fullName'] as String? ?? '';
    final area = user?['area'] as String? ?? '';
    final city = user?['city'] as String? ?? '';
    final location = area.isNotEmpty && city.isNotEmpty ? '$area, $city' : city;
    final wRating = (user?['workerRating'] as num?)?.toDouble() ?? 0;
    final wCount = (user?['workerRatingCount'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: kBlack,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
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
                      child: const Text('Worker',
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
                // Quick action card
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/job-feed'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kBlack,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: kShadow,
                    ),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F77E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('AI Matched',
                                  style: TextStyle(
                                      color: Color(0xFFF9F77E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 12),
                            const Text('Browse Job Cards',
                                style: TextStyle(
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text('Swipe right to bid, left to skip',
                                style: TextStyle(color: kGrey, fontSize: 12)),
                          ])),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F77E),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.style_rounded,
                            color: kBlack, size: 30),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                // Rating card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: kShadow),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Your Rating',
                          style: TextStyle(color: kGrey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          wRating > 0 ? wRating.toStringAsFixed(1) : 'No ratings yet',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: kBlack),
                        ),
                      ]),
                      Text('$wCount reviews',
                          style: const TextStyle(color: kGrey, fontSize: 11)),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF9F77E), Color(0xFFE8E660)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('View Jobs',
                          style: TextStyle(
                              color: kBlack, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                // Tips
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9F77E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: const Color(0xFFF9F77E).withValues(alpha: 0.3))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('💡 How it works',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: kBlack)),
                    const SizedBox(height: 12),
                    _tip('1', 'Browse AI-matched job cards near you'),
                    _tip('2', 'Swipe right to bid or send a counter offer'),
                    _tip('3', 'Poster accepts → Chat & start working'),
                    _tip('4', 'Complete job → Get paid → Leave reviews'),
                  ]),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tip(String num, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: Color(0xFFF9F77E), shape: BoxShape.circle),
            child: Center(
                child: Text(num,
                    style: const TextStyle(
                        color: kBlack,
                        fontSize: 11,
                        fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: kBlack, fontSize: 13))),
        ]),
      );
}
