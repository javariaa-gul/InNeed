import 'package:flutter/material.dart';
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

  void _changeName() {
    final ctrl = TextEditingController(
        text: widget.user?['fullName'] as String? ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _inputSheet(
        title: 'Change Name',
        controller: ctrl,
        hint: 'Full Name',
        onSave: () async {
          if (ctrl.text.trim().isEmpty) return;
          try {
            await _api.updateMe({'fullName': ctrl.text.trim()});
            widget.onRefresh();
            if (mounted) {
              Navigator.pop(context);
              showSnack(context, 'Name updated!', ok: true);
            }
          } catch (e) {
            if (mounted) showSnack(context, e.toString(), err: true);
          }
        },
      ),
    );
  }

  void _changePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 24),
          decoration: BoxDecoration(
              color: kWhite, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: kDivider,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Change Password',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kBlack)),
            const SizedBox(height: 20),
            TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded))),
            const SizedBox(height: 12),
            TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_rounded))),
            const SizedBox(height: 12),
            TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_rounded))),
            const SizedBox(height: 20),
            GradBtn(
              text: 'Update Password',
              onTap: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  showSnack(context, 'Passwords do not match', err: true);
                  return;
                }
                if (newCtrl.text.length < 8) {
                  showSnack(context, 'Password too short', err: true);
                  return;
                }
                try {
                  await _api.updateMe({
                    'oldPassword': oldCtrl.text,
                    'password': newCtrl.text,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    showSnack(context, 'Password updated!', ok: true);
                  }
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), err: true);
                }
              },
              bgColor: kBlack,
              foreColor: kWhite,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _inputSheet({
    required String title,
    required TextEditingController controller,
    required String hint,
    required Future<void> Function() onSave,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24),
      decoration:
          BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: kDivider, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: kBlack)),
        const SizedBox(height: 20),
        TextField(
            controller: controller,
            decoration: InputDecoration(labelText: hint)),
        const SizedBox(height: 20),
        GradBtn(
            text: 'Save',
            onTap: onSave,
            bgColor: kBlack,
            foreColor: kWhite),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial =
        (user?['fullName'] as String? ?? 'A')[0].toUpperCase();
    final role = user?['activeRole']?.toString() ?? 'worker';
    final isPoster = role == 'employer';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBlack,
        title: const Text('Settings',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
        leading: const BackButton(color: kWhite),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
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
                gradient: const LinearGradient(
                    colors: [Color(0xFFF9F77E), Color(0xFFE8E660)]),
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
            buildTag(
                isPoster ? 'EMPLOYER' : 'WORKER',
                isPoster ? kPurple : const Color(0xFFF9F77E)),
          ]),
        ),
        const SizedBox(height: 28),
        _section('Account', [
          _tile(Icons.person_outline_rounded, 'Change Name', kBlue,
              _changeName),
          _tile(Icons.lock_outline_rounded, 'Change Password', kPurple,
              _changePassword),
        ]),
        const SizedBox(height: 16),
        _section('More', [
          _tile(Icons.help_outline_rounded, 'Help & Support', kOrange, () {}),
          _tile(Icons.privacy_tip_outlined, 'Privacy Policy', Colors.teal,
              () {}),
          _tile(Icons.info_outline_rounded, 'About Apka Hunar', kGrey, () {}),
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
      ]),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: kBlack)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: kGrey, size: 18),
        onTap: onTap,
      );
}
