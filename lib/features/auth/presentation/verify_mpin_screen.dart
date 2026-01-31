import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/auth_provider.dart';

class VerifyMpinScreen extends ConsumerStatefulWidget {
  const VerifyMpinScreen({super.key});

  @override
  ConsumerState<VerifyMpinScreen> createState() => _VerifyMpinScreenState();
}

class _VerifyMpinScreenState extends ConsumerState<VerifyMpinScreen> {
  final _mpinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tryBiometricAuth();
  }

  Future<void> _tryBiometricAuth() async {
    final mpinService = ref.read(mpinServiceProvider);
    if (mpinService.isBiometricEnabled) {
      final authenticated = await mpinService.authenticateWithBiometrics();
      if (authenticated && mounted) {
        ref.read(authProvider.notifier).verifyMpin();
        // Router should handle redirection, or manual push:
        // context.go('/student-dashboard'); // Let router decide based on state
      }
    }
  }

  void _verifyMpin() {
    if (_mpinController.text.length == 4) {
      final mpinService = ref.read(mpinServiceProvider);
      if (mpinService.verifyMpin(_mpinController.text)) {
        ref.read(authProvider.notifier).verifyMpin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect MPIN'),
            backgroundColor: Colors.red,
          ),
        );
        _mpinController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 60,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Unlock SVCE',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your MPIN or scan fingerprint',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _mpinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                onChanged: (val) {
                  if (val.length == 4) _verifyMpin();
                },
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              IconButton(
                icon: const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: AppColors.primary,
                ),
                onPressed: _tryBiometricAuth,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                child: const Text('Logout / Switch Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
