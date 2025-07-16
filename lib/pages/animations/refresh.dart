import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class CustomSmartRefresher extends StatelessWidget {
  final Widget child;
  final VoidCallback onRefresh;
  final bool enablePullDown;

  const CustomSmartRefresher({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enablePullDown = true,
  });

  @override
  Widget build(BuildContext context) {
    final RefreshController _refreshController = RefreshController();

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: enablePullDown,
      enablePullUp: false,
      onRefresh: () {
        onRefresh();
        _refreshController.refreshCompleted(); // call when done
      },
      header: const WaterDropHeader(
        complete: Icon(Icons.done, color: Colors.blue),
        refresh: CircularProgressIndicator(color: Colors.blue),
      ),
      child: child,
    );
  }
}
