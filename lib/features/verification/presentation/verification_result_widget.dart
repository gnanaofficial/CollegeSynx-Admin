import 'package:flutter/material.dart';

enum VerificationState { idle, loading, success, failure }

class VerificationResultWidget extends StatefulWidget {
  final VerificationState state;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onManualOverride;

  const VerificationResultWidget({
    super.key,
    required this.state,
    this.message,
    this.onRetry,
    this.onManualOverride,
  });

  @override
  State<VerificationResultWidget> createState() =>
      _VerificationResultWidgetState();
}

class _VerificationResultWidgetState extends State<VerificationResultWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(covariant VerificationResultWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (widget.state == VerificationState.success ||
          widget.state == VerificationState.failure) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 120, width: 120, child: _buildIcon()),
        const SizedBox(height: 24),
        if (widget.message != null)
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getColor(),
            ),
          ),
        const SizedBox(height: 32),
        if (widget.state == VerificationState.failure)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onRetry != null)
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              if (widget.onManualOverride != null)
                TextButton(
                  onPressed: widget.onManualOverride,
                  child: const Text(
                    'Manual Override',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildIcon() {
    switch (widget.state) {
      case VerificationState.loading:
        return const CircularProgressIndicator(strokeWidth: 4);
      case VerificationState.success:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
            child: const Icon(Icons.check, size: 60, color: Colors.white),
          ),
        );
      case VerificationState.failure:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(Icons.close, size: 60, color: Colors.white),
          ),
        );
      case VerificationState.idle:
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getColor() {
    switch (widget.state) {
      case VerificationState.success:
        return Colors.green;
      case VerificationState.failure:
        return Colors.red;
      default:
        return Colors.black87;
    }
  }
}
