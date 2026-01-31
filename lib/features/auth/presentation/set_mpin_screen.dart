import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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

          // Mark verified so strict router logic is satisfied
          ref.read(authProvider.notifier).verifyMpin();

          // Navigate to dashboard
          if (mounted) {
            // Need to trigger router refresh or explicit go
            // Router listener should handle it, but explicit go is safer
            // role based handled by Router redirect mostly, but we are already 'authenticated'
            // check role
            final user = ref.read(authProvider).user;
            if (user?.role.name == 'student') {
              context.go('/student-dashboard');
            } else if (user?.role.name == 'faculty') {
              context.go('/faculty-dashboard');
            } else {
              context.go('/student-dashboard');
            }
          }
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
              const SizedBox(height: 48),
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
