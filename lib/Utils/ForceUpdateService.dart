// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:new_version_plus/new_version_plus.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class ForceUpdateService {
//   static Future<void> check(BuildContext context) async {
//     if (!Platform.isAndroid) return;
//
//     final newVersion = NewVersionPlus(
//       androidId: "com.metaxperts.order_booking_app",
//     );
//
//     try {
//       final status = await newVersion.getVersionStatus();
//
//       if (status != null && status.canUpdate) {
//         _showDialog(context, status.appStoreLink);
//       }
//     } catch (e) {
//       debugPrint("Version check failed: $e");
//     }
//   }
//
//   static void _showDialog(BuildContext context, String url) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // ❌ can't close
//       builder: (_) => WillPopScope(
//         onWillPop: () async => false, // ❌ back button blocked
//         child: AlertDialog(
//           title: const Text("Update Required"),
//           content: const Text(
//             "A new version is available. You must update to continue using this app.",
//           ),
//           actions: [
//             ElevatedButton(
//               onPressed: () async {
//                 await launchUrl(
//                   Uri.parse(url),
//                   mode: LaunchMode.externalApplication,
//                 );
//               },
//               child: const Text("UPDATE"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateService {
  static Future<void> check(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final newVersion = NewVersionPlus(
      androidId: "com.metaxperts.order_booking_app",
    );

    try {
      final status = await newVersion.getVersionStatus();

      if (status != null && status.canUpdate) {
        _showDialog(context, status.appStoreLink, status.storeVersion ?? '');
      }
    } catch (e) {
      debugPrint("Version check failed: $e");
    }
  }

  static void _showDialog(BuildContext context, String url, String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _PlayStoreUpdateDialog(
            url: url,
            newVersion: newVersion,
          ),
        ),
      ),
    );
  }
}

class _PlayStoreUpdateDialog extends StatelessWidget {
  final String url;
  final String newVersion;

  const _PlayStoreUpdateDialog({
    required this.url,
    required this.newVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Google Play Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Google Play logo
                Image.network(
                  'https://www.gstatic.com/android/market_images/web/play_prism_holo_168.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => _GooglePlayIcon(),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Google Play',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F6368),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Title ───
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Update available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Color(0xFF202124),
                letterSpacing: 0,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ─── Subtitle ───
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'To use this app, download the latest version.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5F6368),
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── App Info Row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // App icon placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF1A73E8).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF1A73E8).withOpacity(0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF1A73E8),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Booking App',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 12,
                          color: Color(0xFF5F6368),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          newVersion.isNotEmpty
                              ? 'Version $newVersion'
                              : 'New version',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Divider ───
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EAED)),

          // ─── What's new section ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "What's new",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF202124),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF5F6368),
                  size: 20,
                ),
              ],
            ),
          ),

          // ─── Divider ───
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EAED)),

          // ─── Action Buttons ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // More info (outlined)
                OutlinedButton(
                  onPressed: () async {
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A73E8),
                    side: const BorderSide(color: Color(0xFFDADCE0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'More info',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Update (filled green)
                ElevatedButton(
                  onPressed: () async {
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7E34),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Google Play colored dots icon (fallback)
class _GooglePlayIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF4285F4),
              shape: BoxShape.circle,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFEA4335),
              shape: BoxShape.circle,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF34A853),
              shape: BoxShape.circle,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFBBC05),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}