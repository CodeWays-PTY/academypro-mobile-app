import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../auth/presentation/auth_state.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/app_toast.dart';

class ProfileTabView extends ConsumerStatefulWidget {
  const ProfileTabView({super.key});

  @override
  ConsumerState<ProfileTabView> createState() => _ProfileTabViewState();
}

class _ProfileTabViewState extends ConsumerState<ProfileTabView> {
  late bool _pushNotifications;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load push notification setting from local storage
    final savedPush = LocalStorage.getCachedData('push_notifications_enabled');
    _pushNotifications = savedPush is bool ? savedPush : true;
  }

  Future<void> _handlePushToggle(bool enabled) async {
    setState(() => _pushNotifications = enabled);
    await LocalStorage.cacheData('push_notifications_enabled', enabled);

    final notifService = NotificationService();
    if (enabled) {
      final granted = await notifService.requestPermissions();
      if (granted) {
        final authState = ref.read(authProvider);
        final profile = authState.userProfile ?? LocalStorage.getUserProfile() ?? {};
        final tenant = profile['schoolName'] ?? profile['school_name'] ?? profile['tenant'] ?? 'Hoërskool Overkruin';
        
        // Trigger live push notification to prove it works
        await notifService.showNotification(
          id: 1001,
          title: 'Push Notifications Active',
          body: 'You will now receive live match day alerts and attendance nudges for $tenant.',
        );

        if (mounted) {
          AppToast.showSuccess(
            context,
            title: 'Notifications Enabled',
            message: "You'll receive live alerts and reminders.",
          );
        }
      }
    } else {
      await notifService.cancelAll();
      if (mounted) {
        AppToast.showInfo(
          context,
          title: 'Notifications Off',
          message: 'Push notifications have been turned off.',
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final imagePath = pickedFile.path;
        await ref.read(authProvider.notifier).updateUserProfile({
          'avatarUrl': imagePath,
          'profile_pic': imagePath,
        });

        if (mounted) {
          AppToast.showSuccess(
            context,
            title: 'Photo Updated',
            message: 'Profile picture updated successfully.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Photo Error',
          message: 'Could not select image. Please try again.',
        );
      }
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 20.0,
            bottom: 24.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131B2E),
                ),
              ),
              const SizedBox(height: 4.0),
              const Text(
                'Choose an option to update your display image',
                style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20.0),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Select photo from local device gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Take a New Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Use camera to capture profile picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmailVerificationModal(
    BuildContext context,
    String currentEmail,
    String newEmail,
    Map<String, dynamic> updatedProfile,
  ) {
    final otpController = TextEditingController();
    bool verifying = false;

    final apiClient = ref.read(apiClientProvider);
    apiClient.post(
      '/api/auth/send-email-change-otp',
      data: {'currentEmail': currentEmail, 'newEmail': newEmail},
    ).catchError((e) {
      if (context.mounted) {
        AppToast.showError(context, title: 'Email Dispatch Failed', message: 'Could not send verification code to $newEmail.');
      }
      return Response(requestOptions: RequestOptions(path: '/api/auth/send-email-change-otp'));
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF003EC7), size: 24.0),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verify New Email Address',
                              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              '6-digit code sent to $newEmail',
                              style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: otpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    maxLength: 6,
                    style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, letterSpacing: 8.0),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '• • • • • •',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), letterSpacing: 4.0),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFF003EC7), width: 2.0)),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            final code = otpController.text.trim();
                            if (code.length != 6) {
                              AppToast.showError(context, title: 'Invalid Code', message: 'Please enter the 6-digit verification code.');
                              return;
                            }

                            setModalState(() => verifying = true);

                            try {
                              final res = await apiClient.post(
                                '/api/auth/verify-new-email',
                                data: {
                                  'currentEmail': currentEmail,
                                  'newEmail': newEmail,
                                  'otp': code,
                                },
                              );

                              if (res.statusCode == 200 && res.data['success'] == true) {
                                final finalProfile = Map<String, dynamic>.from(updatedProfile);
                                finalProfile['email'] = newEmail;
                                await ref.read(authProvider.notifier).updateUserProfile(finalProfile);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppToast.showSuccess(
                                    context,
                                    title: 'Email Address Verified',
                                    message: 'Your account email was updated successfully to $newEmail.',
                                  );
                                }
                              } else {
                                setModalState(() => verifying = false);
                                if (context.mounted) {
                                  AppToast.showError(context, title: 'Verification Failed', message: res.data['message'] ?? 'Invalid code');
                                }
                              }
                            } catch (e) {
                              setModalState(() => verifying = false);
                              if (context.mounted) {
                                AppToast.showError(context, title: 'Verification Error', message: 'Failed to verify new email code.');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003EC7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                      elevation: 0,
                    ),
                    child: verifying
                        ? const SizedBox(width: 20.0, height: 20.0, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                        : const Text('Verify & Save Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSMSVerificationModal(
    BuildContext context,
    String phone,
    String name,
    Map<String, dynamic> updatedProfile,
  ) {
    final otpController = TextEditingController();
    bool verifying = false;

    // Trigger SMS dispatch via API
    final apiClient = ref.read(apiClientProvider);
    apiClient.post(
      '/api/sms/send-verification',
      data: {'phone': PhoneUtils.toCleanRSAPhone(phone), 'name': name},
    ).then((res) {
      if (res.data != null && res.data['success'] == true) {
        if (context.mounted) {
          AppToast.showInfo(
            context,
            title: 'SMS Code Sent',
            message: 'A 6-digit verification code has been sent via SMS to $phone.',
          );
        }
      }
    }).catchError((_) {});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Icon(Icons.sms_outlined, color: Color(0xFF2563EB), size: 24.0),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verify Phone Number',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'SMS security code dispatched to $phone',
                              style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: otpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, letterSpacing: 6.0),
                    decoration: InputDecoration(
                      hintText: '• • • • • •',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), letterSpacing: 6.0),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            final entered = otpController.text.trim();
                            if (entered.length < 4) {
                              AppToast.showError(
                                context,
                                title: 'Invalid Code',
                                message: 'Please enter the 6-digit SMS code.',
                              );
                              return;
                            }
                            setModalState(() => verifying = true);

                            try {
                              final apiClient = ref.read(apiClientProvider);
                              final res = await apiClient.post(
                                '/api/coach/verify-sms-otp',
                                data: {'phone': phone, 'code': entered},
                              );

                              if (res.statusCode == 200 && res.data['success'] == true) {
                                final finalProfile = Map<String, dynamic>.from(updatedProfile);
                                finalProfile['phone'] = phone;
                                finalProfile['phoneVerified'] = true;
                                finalProfile['phone_verified'] = true;
                                await ref.read(authProvider.notifier).updateUserProfile(finalProfile);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppToast.showSuccess(
                                    context,
                                    title: 'Phone Number Verified',
                                    message: 'Phone number $phone verified and saved successfully.',
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  AppToast.showError(
                                    context,
                                    title: 'Verification Failed',
                                    message: res.data?['message'] ?? 'Invalid code. Please try again.',
                                  );
                                }
                              }
                            } catch (err) {
                              if (context.mounted) {
                                AppToast.showError(
                                  context,
                                  title: 'Verification Failed',
                                  message: 'Invalid or expired code. Please check your SMS and try again.',
                                );
                              }
                            } finally {
                              setModalState(() => verifying = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003EC7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    ),
                    child: verifying
                        ? const SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                          )
                        : const Text(
                            'Verify Code & Save Profile',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEditPersonalInfoSheet(BuildContext context, Map<String, dynamic> currentProfile) {
    HapticFeedback.lightImpact();

    final firstNameController = TextEditingController(
      text: currentProfile['first_name'] ?? currentProfile['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: currentProfile['last_name'] ?? currentProfile['lastName'] ?? '',
    );
    final emailController = TextEditingController(
      text: currentProfile['email'] ?? '',
    );
    final phoneController = TextEditingController(
      text: currentProfile['phone'] ?? '',
    );
    final tenantController = TextEditingController(
      text: currentProfile['schoolName'] ?? currentProfile['school_name'] ?? currentProfile['tenant'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Personal Info',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Update your profile details across AcademyPro & uSPORT network',
                  style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24.0),

                // First Name Input
                _buildInputField(
                  controller: firstNameController,
                  label: 'First Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16.0),

                // Last Name Input
                _buildInputField(
                  controller: lastNameController,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16.0),

                // Email Input
                _buildInputField(
                  controller: emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16.0),

                // Phone Input
                _buildInputField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16.0),

                // School Tenant Input (Read-Only, Managed by Admin)
                _buildInputField(
                  controller: tenantController,
                  label: 'Academy Tenant / School (Managed by Admin)',
                  icon: Icons.account_balance_outlined,
                  readOnly: true,
                ),
                const SizedBox(height: 28.0),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52.0,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      final oldEmail = (currentProfile['email'] ?? '').toString().trim().toLowerCase();
                      final newEmail = emailController.text.trim().toLowerCase();
                      final isEmailChanged = newEmail.isNotEmpty && newEmail != oldEmail;

                      final newPhone = PhoneUtils.formatRSAPhone(phoneController.text.trim());
                      final oldPhone = currentProfile['phone'] ?? '';
                      final isPhoneChanged = newPhone != oldPhone;

                      final updated = {
                        'first_name': firstNameController.text.trim(),
                        'firstName': firstNameController.text.trim(),
                        'last_name': lastNameController.text.trim(),
                        'lastName': lastNameController.text.trim(),
                        'email': oldEmail,
                        'phone': newPhone,
                        'phoneVerified': !isPhoneChanged && (currentProfile['phoneVerified'] == true),
                        'schoolName': tenantController.text.trim(),
                        'school_name': tenantController.text.trim(),
                        'tenant': tenantController.text.trim(),
                      };

                      await ref.read(authProvider.notifier).updateUserProfile(updated);

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (isPhoneChanged) {
                          _showSMSVerificationModal(
                            context,
                            newPhone,
                            firstNameController.text.trim(),
                            updated,
                          );
                        } else if (isEmailChanged) {
                          _showEmailVerificationModal(
                            context,
                            oldEmail,
                            newEmail,
                            updated,
                          );
                        } else {
                          AppToast.showSuccess(
                            context,
                            title: 'Profile Saved',
                            message: 'Personal profile details updated successfully.',
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003EC7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6.0),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            fontSize: 15.0,
          ),
          decoration: InputDecoration(
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            filled: true,
            suffixIcon: readOnly ? const Icon(Icons.lock_outlined, color: Color(0xFF94A3B8), size: 18.0) : null,
            prefixIcon: keyboardType == TextInputType.phone
                ? Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('🇿🇦', style: TextStyle(fontSize: 16.0)),
                        SizedBox(width: 4.0),
                        Text(
                          '+27',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003EC7), fontSize: 14.0),
                        ),
                        SizedBox(width: 6.0),
                        Icon(Icons.phone_outlined, color: Color(0xFF2563EB), size: 18.0),
                      ],
                    ),
                  )
                : Icon(icon, color: const Color(0xFF2563EB), size: 20.0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.0),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.0),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userProfile = authState.userProfile ?? LocalStorage.getUserProfile() ?? {};

    final firstName = userProfile['first_name'] ?? userProfile['firstName'] ?? '';
    final lastName = userProfile['last_name'] ?? userProfile['lastName'] ?? '';
    final email = userProfile['email'] ?? authState.email ?? '';
    final role = (userProfile['role'] ?? 'Head Coach').toString().toUpperCase();
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

    // Dynamic School / Tenant Name
    final rawSchool = userProfile['schoolName'] ?? userProfile['school_name'] ?? userProfile['tenant'] ?? 'Hoërskool Overkruin';
    final dynamicTenant = rawSchool.toString().replaceAll('Hoërskool ', '');

    // Avatar image check
    final avatarPath = userProfile['avatarUrl'] ?? userProfile['profile_pic'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 16.0,
          bottom: 100.0 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header Title
            const Text(
              'Coach Profile',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Manage your credentials, preferences, and account info.',
              style: TextStyle(
                fontSize: 14.0,
                color: Color(0xFF434656),
              ),
            ),
            const SizedBox(height: 20.0),

            // Profile Header Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Avatar Circle with Camera Upload Hook
                  GestureDetector(
                    onTap: () => _showImagePickerOptions(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 72.0,
                          height: 72.0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF003EC7), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF003EC7).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: avatarPath != null && avatarPath.toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(36.0),
                                  child: avatarPath.toString().startsWith('http')
                                      ? Image.network(
                                          avatarPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Center(
                                            child: Text(
                                              initials.isNotEmpty ? initials : 'AP',
                                              style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      : Image.file(
                                          File(avatarPath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Center(
                                            child: Text(
                                              initials.isNotEmpty ? initials : 'AP',
                                              style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                )
                              : Center(
                                  child: Text(
                                    initials.isNotEmpty ? initials : 'AP',
                                    style: const TextStyle(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.0),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$firstName $lastName',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13.0,
                            color: Color(0xFF505F76),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDE1FF),
                                borderRadius: BorderRadius.circular(999.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_user_outlined, size: 12.0, color: Color(0xFF0038B6)),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0038B6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Dynamic Quick Info Grid
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatTile(
                    label: 'ACADEMY TENANT',
                    value: dynamicTenant,
                    icon: Icons.account_balance,
                    iconColor: const Color(0xFF003EC7),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _buildQuickStatTile(
                    label: 'SECURITY STATUS',
                    value: 'Verified',
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF166534),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28.0),

            // Section 1: Account Settings (Personal Info opens tab/sheet)
            _buildSectionTitle('ACCOUNT & SECURITY'),
            const SizedBox(height: 10.0),
            _buildCardGroup([
              _buildSettingTile(
                icon: Icons.person_outline,
                title: 'Personal Info',
                subtitle: 'Edit name, contact details & academy tenant',
                onTap: () => _openEditPersonalInfoSheet(context, userProfile),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSettingTile(
                icon: Icons.camera_alt_outlined,
                title: 'Profile Picture',
                subtitle: 'Upload or update your avatar photo',
                onTap: () => _showImagePickerOptions(context),
              ),
            ]),
            const SizedBox(height: 24.0),

            // Section 2: Real Push Notifications & Sync
            _buildSectionTitle('PREFERENCES & NOTIFICATIONS'),
            const SizedBox(height: 10.0),
            _buildCardGroup([
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                subtitle: 'Receive match alerts and attendance nudges',
                value: _pushNotifications,
                onChanged: (val) => _handlePushToggle(val),
              ),
            ]),
            const SizedBox(height: 16.0),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 52.0,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, size: 20.0),
                label: const Text(
                  'Sign Out of AcademyPro',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Delete Account Button (Apple App Store Guideline 5.1.1(v))
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: TextButton.icon(
                onPressed: () => _confirmDeleteAccount(context),
                icon: const Icon(Icons.delete_forever, size: 18.0, color: Color(0xFFBA1A1A)),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            const Center(
              child: Text(
                '© 2026 CodeWays PTY Ltd. All rights reserved.',
                style: TextStyle(
                  fontSize: 11.0,
                  color: Color(0xFF737688),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(icon, size: 18.0, color: iconColor),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF737688),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131B2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
        color: Color(0xFF737688),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(icon, size: 20.0, color: const Color(0xFF505F76)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF131B2E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.0,
          color: Color(0xFF737688),
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(icon, size: 20.0, color: const Color(0xFF505F76)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF131B2E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.0,
          color: Color(0xFF737688),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: const Color(0xFF003EC7),
        onChanged: onChanged,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }



  void _confirmLogout(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        actionsPadding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of your AcademyPro coach account?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              foregroundColor: const Color(0xFF475569),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        actionsPadding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A))),
        content: const Text(
          'Are you sure you want to permanently delete your AcademyPro account? All associated account data, profile details, and preferences will be permanently erased. This action cannot be undone.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              foregroundColor: const Color(0xFF475569),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authState = ref.read(authProvider);
              final email = authState.email ?? authState.userProfile?['email'] ?? '';
              final userId = authState.userProfile?['id']?.toString() ?? '';
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.post('/api/user/delete-account', data: {
                  'email': email,
                  'userId': userId,
                });
              } catch (e) {
                debugPrint('[Account Deletion Error] $e');
              }
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
