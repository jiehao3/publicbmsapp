import 'package:flutter/material.dart';

class LoadingAnimation extends StatelessWidget {
  final String message;
  final Color? color;

  const LoadingAnimation({
    super.key,
    this.message = 'Loading Data...',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: color ?? Theme.of(context).primaryColor,
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: color ?? Theme.of(context).primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your data',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}