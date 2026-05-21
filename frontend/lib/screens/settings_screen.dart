import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  const SettingsScreen(
      {super.key,
      required this.user,
      required this.onLogout,
      required this.onRefresh});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  bool _switching = false;

  Future<void> _switchRole() async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      final data = await _api.switchRole();
      if (mounted) {
        final newRole =
            (data['activeRole'] ?? 'worker').toString().toLowerCase();
        widget.onRefresh();

        // Show success message
        showSnack(
          context,
          'Switched to ${newRole.toUpperCase()} mode',
          ok: true,
        );

        // Wait a moment then redirect to dashboard
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/dashboard',
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _changeField({
    required String title,
    required String key,
    required String hint,
    String? initial,
    TextInputType keyboardType = TextInputType.text,
    String successMessage = 'Updated successfully!',
  }) {
    final ctrl = TextEditingController(text: initial ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _inputSheet(
        title: title,
        controller: ctrl,
        hint: hint,
        keyboardType: keyboardType,
        onSave: () async {
          if (ctrl.text.trim().isEmpty) return;
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(context);
          try {
            await _api.updateMe({key: ctrl.text.trim()});
            widget.onRefresh();
            if (mounted) {
              nav.pop();
              messenger.showSnackBar(SnackBar(
                content:
                    Text(successMessage, style: const TextStyle(color: kBlack)),
                backgroundColor: kPrimaryLime,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            }
          } catch (e) {
            if (mounted) showSnack(context, e.toString(), err: true);
          }
        },
      ),
    );
  }

  void _changeName() {
    _changeField(
      title: 'Change Name',
      key: 'fullName',
      hint: 'Enter your full name',
      initial: widget.user?['fullName'],
      successMessage: 'Name updated successfully!',
    );
  }

  void _changePhone() {
    _changeField(
      title: 'Change Phone Number',
      key: 'phoneNumber',
      hint: 'Enter your phone number',
      initial: widget.user?['phoneNumber'],
      keyboardType: TextInputType.phone,
      successMessage: 'Phone number updated successfully!',
    );
  }

  void _changePassword() {
    _changeField(
      title: 'Change Password',
      key: 'password',
      hint: 'Enter new password',
      keyboardType: TextInputType.visiblePassword,
      successMessage: 'Password updated successfully!',
    );
  }

  Widget _inputSheet({
    required String title,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: kBlack)),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.phone
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            labelText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GradBtn(
            text: 'Save', onTap: onSave, bgColor: kBlack, foreColor: kWhite),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = (user?['fullName'] as String? ?? 'A')[0].toUpperCase();
    final role = user?['activeRole']?.toString() ?? 'worker';
    final isPoster = role == 'employer';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBlack,
        title: const Text('Settings & Account',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
        leading: const BackButton(color: kWhite),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              // Profile mini card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: kShadow),
                child: Row(children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFEF88E),
                    ),
                    child: Center(
                        child: Text(initial,
                            style: const TextStyle(
                                color: kBlack,
                                fontSize: 22,
                                fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(user?['fullName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: kBlack)),
                        Text(user?['phoneNumber'] ?? '',
                            style: const TextStyle(color: kGrey, fontSize: 12)),
                      ])),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF88E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPoster ? 'EMPLOYER' : 'WORKER',
                      style: const TextStyle(
                        color: kBlack,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              _section('Account', [
                _tile(Icons.person_outline_rounded, 'Change Name', kBlack,
                    _changeName),
                _tile(Icons.phone_android_rounded, 'Change Phone Number',
                    kBlack, _changePhone),
                _tile(Icons.lock_outline_rounded, 'Change Password', kBlack,
                    _changePassword),
              ]),
              const SizedBox(height: 16),
              _section('More', [
                _tile(Icons.help_outline_rounded, 'Help & Support', kBlack,
                    _openHelp),
                _tile(Icons.privacy_tip_outlined, 'Privacy Policy', kBlack,
                    _openPrivacy),
                _tile(Icons.info_outline_rounded, 'About InNeed', kBlack,
                    _openAbout),
              ]),
              const SizedBox(height: 24),
              // Logout
              GestureDetector(
                onTap: widget.onLogout,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kRed.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: kRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.logout_rounded,
                            color: kRed, size: 20)),
                    const SizedBox(width: 14),
                    const Text('Logout',
                        style: TextStyle(
                            color: kRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: kRed),
                  ]),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 22,
            child: _FloatingSwapButton(
              isLoading: _switching,
              onPressed: _switching ? null : _switchRole,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<Widget> rows) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kGrey.withValues(alpha: 0.8),
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ACard(
            padding: EdgeInsets.zero,
            child: Column(
                children: List.generate(
                    rows.length,
                    (i) => Column(children: [
                          rows[i],
                          if (i < rows.length - 1)
                            Divider(height: 0, indent: 70, color: kDivider),
                        ])))),
      ]);

  Widget _tile(IconData icon, String title, Color color, VoidCallback onTap) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFFEF88E),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: kBlack, size: 19)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: kBlack)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: kBlack, size: 18),
        onTap: onTap,
      );

  void _openHelp() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _InfoPage(
        title: 'Help & Support',
        icon: Icons.help_outline_rounded,
        lines: const [
          'Need help using InNeed? Start with the Settings screen to update your name, phone, and password.',
          '• To view or reply to a job, open the relevant job card and use the chat or bids actions shown there.',
          '• If a button does not work, close and reopen the page, then log out and log back in once.',
          '• For posting jobs, use the plus button at the bottom of the dashboard and fill the required fields carefully.',
          '• For profile changes, go to Settings & Account and use the matching option for each detail.',
        ],
      ),
    ));
  }

  void _openPrivacy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _InfoPage(
        title: 'Privacy Policy',
        icon: Icons.privacy_tip_outlined,
        lines: const [
          'Your data is used only to run InNeed features and improve matching.',
          '• Profile details help workers and employers find the right jobs and bids.',
          '• Location data is used only for nearby matching and display purposes.',
          '• Messages, reviews, and profile information stay inside the app flow.',
          '• You can update your personal information any time from Settings.',
        ],
      ),
    ));
  }

  void _openAbout() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _InfoPage(
        title: 'About InNeed',
        icon: Icons.info_outline_rounded,
        lines: const [
          'InNeed connects workers and employers in one place.',
          '• Post jobs, place bids, chat, and track progress from one simple app.',
          '• Built for a clean black and yellow experience with fast navigation.',
          '• Designed to keep job work, communication, and reviews easy to manage.',
          '• InNeed focuses on practical features that are quick to understand.',
        ],
      ),
    ));
  }
}

class _InfoPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> lines;

  const _InfoPage({
    required this.title,
    required this.icon,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBlack,
        leading: const BackButton(color: kWhite),
        title: Text(title,
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: kShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF88E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: kBlack, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: kBlack,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// Floating circular swap button with continuous smooth animation
class _FloatingSwapButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _FloatingSwapButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_FloatingSwapButton> createState() => _FloatingSwapButtonState();
}

class _FloatingSwapButtonState extends State<_FloatingSwapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = sin(_controller.value * pi * 2) * 10;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kBlack.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: Offset(0, 8 + offset.abs() * 0.5),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: widget.onPressed,
              backgroundColor: kBlack,
              foregroundColor: const Color(0xFFFEF88E),
              elevation: 8,
              highlightElevation: 12,
              shape: const CircleBorder(),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFEF88E),
                        ),
                      ),
                    )
                  : const Icon(Icons.swap_horiz_rounded, size: 36),
            ),
          ),
        );
      },
    );
  }
}
