import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/password_validator.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _skills = TextEditingController();

  String _role = 'worker';
  bool _showPass = false, _showConfirm = false;
  bool _loading = false, _locLoading = false;
  double? _lat, _lon;

  PasswordStrength _strength = PasswordStrength(
      hasUpper: false,
      hasLower: false,
      hasNum: false,
      hasSpecial: false,
      hasLen: false);

  // FIX: Declared as static so they can be const inside the class
  static const Color splashLime = Color(0xFFFEFD99);
  static const Color splashDark = Color(0xFF1A1A1A);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locLoading = true);
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        if (!mounted) return;
        showSnack(context, 'Enable location in Settings', err: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));

      if (!mounted) return; // Added mounted check for safety
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });
      showSnack(context, 'Location captured ✓', ok: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not get location', err: true);
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_strength.isStrong) {
      showSnack(context, 'Password is too weak', err: true);
      return;
    }
    if (_pass.text != _confirm.text) {
      showSnack(context, 'Passwords do not match', err: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.signup(
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        password: _pass.text,
        activeRole: _role,
        skills: _role == 'worker' && _skills.text.trim().isNotEmpty
            ? _skills.text.trim()
            : null,
        lat: _lat,
        lon: _lon,
      );
      if (mounted) {
        showSnack(context, 'Welcome to InNeed!', ok: true);
        await Future.delayed(const Duration(milliseconds: 600));
        // NEW USER FLOW: After successful signup, show onboarding screen
        // The onboarding screen will mark tutorial as seen when user completes/skips it
        if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: splashLime,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: splashDark),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        title: const Text('JOIN INNEED',
            style: TextStyle(
                color: splashDark,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Create Account',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: splashDark,
                      letterSpacing: -1)),
              const Text('Start your professional journey today.',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              Row(children: [
                Expanded(
                    child: _roleCard(
                        'worker', Icons.engineering_rounded, 'Worker')),
                const SizedBox(width: 15),
                Expanded(
                    child: _roleCard(
                        'employer', Icons.business_center_rounded, 'Employer')),
              ]),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: splashDark,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    _buildField(_name, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 18),
                    _buildField(
                        _phone, 'Phone Number', Icons.phone_android_outlined,
                        keyboard: TextInputType.phone),
                    if (_role == 'worker') ...[
                      const SizedBox(height: 18),
                      _buildField(_skills, 'Skills (e.g. Electrician)',
                          Icons.bolt_rounded),
                    ],
                    const SizedBox(height: 18),
                    _buildPassField(_pass, 'Password', _showPass,
                        () => setState(() => _showPass = !_showPass),
                        onChanged: (v) => setState(
                            () => _strength = PasswordValidator.validate(v))),
                    if (_pass.text.isNotEmpty) _strengthIndicator(),
                    const SizedBox(height: 18),
                    _buildPassField(_confirm, 'Confirm Password', _showConfirm,
                        () => setState(() => _showConfirm = !_showConfirm)),
                    const SizedBox(height: 25),
                    _locationPicker(),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: splashLime,
                          foregroundColor: splashDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: splashDark)
                            : const Text('CREATE ACCOUNT',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Already have an account? Login',
                      style: TextStyle(
                          color: splashDark, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(String val, IconData icon, String label) {
    final bool isSelected = _role == val;
    return GestureDetector(
      onTap: () => setState(() => _role = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? splashDark : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? splashDark : Colors.black12, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? splashLime : splashDark, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : splashDark,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDeco(label, icon),
    );
  }

  Widget _buildPassField(TextEditingController ctrl, String label, bool visible,
      VoidCallback toggle,
      {Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDeco(label, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
              color: splashLime.withValues(alpha: 0.5)),
          onPressed: toggle,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: splashLime, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: splashLime)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }

  Widget _strengthIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _strength.percent / 100,
              backgroundColor: Colors.white10,
              color: _strength.percent > 70
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(_strength.label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _locationPicker() {
    return InkWell(
      onTap: _getLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _lat != null
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: _lat != null ? Colors.greenAccent : Colors.white10),
        ),
        child: Row(
          children: [
            _locLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: splashLime))
                : Icon(_lat != null ? Icons.location_on : Icons.my_location,
                    color: _lat != null ? Colors.greenAccent : splashLime),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _lat != null
                          ? 'Location Captured ✓'
                          : 'Tap to capture location',
                      style: TextStyle(
                          color: _lat != null ? Colors.greenAccent : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (_lat != null)
                    Text(
                      'Area & city will be auto-detected',
                      style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.7),
                          fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
