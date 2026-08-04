import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_toast.dart';
import 'auth_state.dart';
import 'coach_welcome_wizard_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../student/presentation/student_dashboard_screen.dart';
import '../../parent/presentation/parent_dashboard_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _resendTimerSeconds = 30;
  Timer? _timer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimerSeconds = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendTimerSeconds--;
        });
      }
    });
  }

  void _handleSendOtp() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final success = await ref.read(authProvider.notifier).sendOtp(email);
      if (success) {
        _startResendTimer();
        if (mounted) {
          AppToast.showSuccess(
            context,
            title: 'Verification Code Sent',
            message: 'A 6-digit OTP code was sent to $email. Valid for 10 minutes.',
          );
        }
      } else {
        if (mounted) {
          final errorMsg = ref.read(authProvider).errorMessage ?? 'Failed to send login code. Please try again.';
          AppToast.showError(
            context,
            title: 'Request Failed',
            message: errorMsg,
          );
        }
      }
    }
  }

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      AppToast.showError(
        context,
        title: 'Invalid Security Code',
        message: 'Please enter the complete 6-digit code sent to your email.',
      );
      return;
    }
    
    final success = await ref.read(authProvider.notifier).verifyOtp(otp);
    if (success) {
      final profile = ref.read(authProvider).userProfile;
      final role = (profile?['role'] ?? '').toString().trim();
      final firstName = (profile?['first_name'] ?? '').toString().trim();
      final lastName = (profile?['last_name'] ?? profile?['surname'] ?? '').toString().trim();
      final isFirstTime = profile?['is_first_time'] == true || profile?['is_first_time'] == 1 || (firstName.isEmpty && lastName.isEmpty);
      
      Widget targetScreen;
      if (role == 'Headmaster' || role == 'Coach') {
        if (isFirstTime) {
          targetScreen = const CoachWelcomeWizardScreen();
        } else {
          targetScreen = const DashboardScreen();
        }
      } else if (role == 'Parent') {
        targetScreen = const ParentDashboardScreen();
      } else if (role == 'Student') {
        targetScreen = const StudentDashboardScreen();
      } else {
        if (mounted) {
          AppToast.showError(
            context,
            title: 'Unauthorized Role',
            message: 'Your account role ("$role") is invalid. Valid roles are Headmaster, Coach, Student, Parent.',
          );
        }
        return;
      }

      if (mounted) {
        AppToast.showSuccess(
          context,
          title: 'Sign In Successful',
          message: 'Welcome to AcademyPro!',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      }
    } else {
      if (mounted) {
        final errorMsg = ref.read(authProvider).errorMessage ?? 'Invalid verification code. Please check your code and try again.';
        AppToast.showError(
          context,
          title: 'Verification Failed',
          message: errorMsg,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AcademyPro Branding Logo section
              Center(
                child: Container(
                  width: 100.0,
                  height: 100.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 20.0,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.sports,
                        size: 64.0,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'AcademyPro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1.0,
                ),
              ),
              const Text(
                'COACH & ATHLETE PLATFORM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 36.0),

              // Form Container Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (authState.status == AuthStatus.unauthenticated || authState.status == AuthStatus.error) ...[
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          const Text(
                            'Enter your registered email address to request a one-time login code.',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email address';
                              }
                              // Simple email regex validation
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24.0),
                          if (authState.errorMessage != null) ...[
                            Text(
                              authState.errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13.0),
                            ),
                            const SizedBox(height: 12.0),
                          ],
                          ElevatedButton(
                            onPressed: isAuthenticating ? null : _handleSendOtp,
                            child: isAuthenticating
                                ? const SizedBox(
                                    height: 20.0,
                                    width: 20.0,
                                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                  )
                                : const Text('Send Login Code'),
                          ),
                        ] else ...[
                          const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'We sent a 6-digit login code to:\n${authState.email}',
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            textAlign: TextAlign.center,
                            onChanged: (val) {
                              if (val.trim().length == 6 && !isAuthenticating) {
                                FocusScope.of(context).unfocus();
                                _handleVerifyOtp();
                              }
                            },
                            style: const TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8.0,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'One-Time Code',
                              hintText: '******',
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_open_outlined, color: Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          if (authState.errorMessage != null) ...[
                            Text(
                              authState.errorMessage!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13.0),
                            ),
                            const SizedBox(height: 12.0),
                          ],
                          ElevatedButton(
                            onPressed: isAuthenticating ? null : _handleVerifyOtp,
                            child: isAuthenticating
                                ? const SizedBox(
                                    height: 20.0,
                                    width: 20.0,
                                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                  )
                                : const Text('Verify & Sign In'),
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  ref.read(authProvider.notifier).logout();
                                },
                                child: const Text('Back to Login'),
                              ),
                              TextButton(
                                onPressed: _resendTimerSeconds > 0
                                    ? null
                                    : () {
                                        ref.read(authProvider.notifier).sendOtp(authState.email!);
                                        _startResendTimer();
                                      },
                                child: Text(_resendTimerSeconds > 0
                                    ? 'Resend in ${_resendTimerSeconds}s'
                                    : 'Resend Code'),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
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
