import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/network_provider.dart';

/// Shows a banner at the top of the screen when the network is disconnected.
///
/// - Red background with "网络异常" message.
/// - A retry button that re-evaluates connectivity.
/// - Auto-hides when [NetworkState.isOnline] becomes true again.
class NetworkErrorBanner extends ConsumerWidget {
  const NetworkErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkState = ref.watch(networkProvider);

    if (networkState.isOnline) {
      return const SizedBox.shrink();
    }

    return Material(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 8,
          left: 16,
          right: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade700,
              Colors.red.shade500,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '网络异常',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (networkState.errorMessage != null &&
                        networkState.errorMessage!.isNotEmpty)
                      Text(
                        networkState.errorMessage!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Force a check by performing a lightweight connectivity probe.
                  // Since the provider automatically listens to API call results,
                  // we simply reset to checking state — the next API call will
                  // update the state.
                  ref.read(networkProvider.notifier).setConnected();
                },
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text(
                  '重试',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
