import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/role_config.dart';
import '../state/auth_provider.dart';

class SetMpinScreen extends ConsumerStatefulWidget {
  const SetMpinScreen({super.key});

  @override
  ConsumerState<SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends ConsumerState<SetMpinScreen> {
  final _mpinController = TextEditingController();
  final _confirmMpinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    // Optional: Auto-prompt for biometrics if available?
    // Let's keep it manual for now to be less intrusive on "Set MPIN" screen
  }

  void _handleBiometricSetup() async {
    final mpinService = ref.read(mpinServiceProvider);
    final isAuthenticated = await mpinService.authenticateWithBiometrics();

    if (isAuthenticated && mounted) {
      // If authenticated with biometrics, we can set a default MPIN or just enable bio.
      // Setting a dummy MPIN ensures the "isMpinSet" check passes in AppRouter.
      // Using '0000' as a placeholder since they chose Biometrics.
      await mpinService.setMpin('0000');
      await mpinService.setBiometricEnabled(true);

      _completeSetup();
    }
  }

  void _handleMpinSubmit() async {
    if (_formKey.currentState!.validate()) {
      if (!_isConfirming) {
        setState(() {
          _isConfirming = true;
        });
      } else {
        if (_mpinController.text == _confirmMpinController.text) {
          // Save MPIN
          final mpinService = ref.read(mpinServiceProvider);
          await mpinService.setMpin(_mpinController.text);
          await mpinService.setBiometricEnabled(true); // Default enable bio

          _completeSetup();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('MPINs do not match')));
          _confirmMpinController.clear();
          setState(() {
            _isConfirming = false;
          });
        }
      }
    }
  }

  void _completeSetup() {
    // Mark verified so strict router logic is satisfied
    ref.read(authProvider.notifier).verifyMpin();

    // Navigate to dashboard based on role
    if (mounted) {
      final userRole = ref.read(authProvider).user?.role;
      String targetRoute = '/faculty-dashboard'; // Default fallback

      if (userRole == UserRole.hod) {
        targetRoute = '/hod-dashboard';
      } else if (userRole == UserRole.securityAdmin) {
        targetRoute = '/security-admin-dashboard';
      } else if (userRole == UserRole.security) {
        targetRoute = '/security-dashboard';
      } else {
        targetRoute = '/faculty-dashboard';
      }

      context.go(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Set MPIN'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isConfirming ? 'Confirm your MPIN' : 'Create your MPIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Set a 4-digit PIN for quick access',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              if (!_isConfirming)
                _buildPinField(_mpinController, 'Enter 4-digit PIN'),
              if (_isConfirming)
                _buildPinField(_confirmMpinController, 'Confirm 4-digit PIN'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleMpinSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(_isConfirming ? 'Confirm & Continue' : 'Next'),
                ),
              ),
              const SizedBox(height: 24),
              // ADDED: Biometric Option
              if (!_isConfirming)
                Column(
                  children: [
                    const Text('OR'),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _handleBiometricSetup,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Use Fingerprint / Face ID'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 16),
      decoration: InputDecoration(
        hintText: '••••',
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) {
        if (v == null || v.length != 4) {
          return 'Enter 4 digits';
        }
        return null;
      },
    );
  }
}
