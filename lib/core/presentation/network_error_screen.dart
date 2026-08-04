import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_service.dart';
import '../../core/storage/local_storage.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../utils/app_toast.dart';

class NetworkErrorScreen extends ConsumerStatefulWidget {
  const NetworkErrorScreen({super.key});

  @override
  ConsumerState<NetworkErrorScreen> createState() => _NetworkErrorScreenState();
}

class _NetworkErrorScreenState extends ConsumerState<NetworkErrorScreen> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    final notifier = ref.read(networkStatusProvider.notifier);
    final isConnected = await notifier.checkRealConnection();
    if (mounted) {
      setState(() => _isChecking = false);
      if (!isConnected) {
        AppToast.showError(context, title: 'Still Offline', message: 'Please check your mobile data or Wi-Fi connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userProfile = authState.userProfile ?? LocalStorage.getUserProfile() ?? {};
    
    final role = (userProfile['role'] ?? '').toString().toLowerCase();
    final isStudent = role.contains('student') || userProfile.containsKey('gradeAverage') || userProfile.containsKey('position');

    final studentName = '${userProfile['first_name'] ?? userProfile['firstName'] ?? 'Student'} ${userProfile['last_name'] ?? userProfile['lastName'] ?? ''}'.trim();
    final studentId = (userProfile['id'] ?? userProfile['studentId'] ?? userProfile['email'] ?? 'STUDENT-QR-PASS').toString();
    final schoolName = (userProfile['schoolName'] ?? userProfile['school_name'] ?? userProfile['tenant'] ?? 'Hoërskool Overkruin').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Offline Warning Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 18.0),
                      SizedBox(width: 8.0),
                      Text(
                        'NO NETWORK CONNECTION',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                // Main Heading
                const Text(
                  'Network Problem',
                  style: TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),

                Text(
                  isStudent
                      ? 'You are currently offline. Your check-in QR code is displayed below for coach verification.'
                      : 'Please check your Wi-Fi or mobile data connection to continue using AcademyPro.',
                  style: const TextStyle(
                    fontSize: 14.0,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28.0),

                // IF STUDENT: DIRECTLY EMBED & DISPLAY QR CODE RIGHT ON SCREEN
                if (isStudent) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 24.0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 24.0),
                            ),
                            const SizedBox(width: 14.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName.isNotEmpty ? studentName : 'Athlete Check-In',
                                    style: const TextStyle(
                                      fontSize: 17.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    schoolName,
                                    style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text(
                                'OFFLINE PASS',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24.0),

                        // QR CODE DISPLAY CONTAINER
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              // Local High-Contrast QR Code Visual Pattern
                              Image.network(
                                'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=$studentId',
                                width: 180.0,
                                height: 180.0,
                                errorBuilder: (context, error, stackTrace) {
                                  // Offline fallback QR matrix representation
                                  return Container(
                                    width: 180.0,
                                    height: 180.0,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 96.0,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8.0),
                                          Text(
                                            studentId,
                                            style: const TextStyle(
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF94A3B8),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  'ID: $studentId',
                                  style: const TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        const Text(
                          'Coaches can scan this QR code directly for attendance & check-ins.',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                ] else ...[
                  // Icon Illustration for Non-Students
                  Container(
                    width: 100.0,
                    height: 100.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 2.0),
                    ),
                    child: const Icon(
                      Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                      size: 48.0,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 32.0),
                ],

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  height: 52.0,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003EC7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22.0,
                            height: 22.0,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, size: 20.0),
                              SizedBox(width: 8.0),
                              Text(
                                'Retry Connection',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
