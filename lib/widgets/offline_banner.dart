import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../utils/app_strings.dart';

/// Slim banner shown above the whole app while the device has no network.
/// Reassures the user that offline work is safe: everything saves locally.
class OfflineBanner extends StatelessWidget {
  final String lang;

  const OfflineBanner({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final offline =
            results != null &&
            (results.isEmpty ||
                results.every((r) => r == ConnectivityResult.none));
        if (!offline) return const SizedBox.shrink();

        return Material(
          color: const Color(0xFF92400E), // amber-800: visible, not alarming
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppStrings.get('offline_banner', lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
