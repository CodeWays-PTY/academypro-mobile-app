import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/country_code_picker.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import 'auth_state.dart';

class CoachWelcomeWizardScreen extends ConsumerStatefulWidget {
  const CoachWelcomeWizardScreen({super.key});

  @override
  ConsumerState<CoachWelcomeWizardScreen> createState() => _CoachWelcomeWizardScreenState();
}

class _CoachWelcomeWizardScreenState extends ConsumerState<CoachWelcomeWizardScreen> {
  final PageController _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _currentStep = 0;
  XFile? _selectedImage;
  bool _isSubmitting = false;
  CountryCode _selectedCountry = CountryCodePicker.defaultCountries[0]; // Defaults to RSA (🇿🇦 +27)

  @override
  void initState() {
    super.initState();
    // Pre-populate if profile already has partial details
    final profile = ref.read(authProvider).userProfile;
    if (profile != null) {
      _firstNameController.text = (profile['first_name'] ?? '').toString();
      _lastNameController.text = (profile['last_name'] ?? profile['surname'] ?? '').toString();
      _phoneController.text = (profile['phone'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Image Selection Failed',
          message: 'Unable to select profile picture. You can skip this step for now.',
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'Select Profile Picture',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003EC7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Color(0xFF003EC7)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8.0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003EC7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF003EC7)),
                  ),
                  title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 8.0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextPage() {
    if (_step1FormKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        ref.read(authProvider.notifier).updateUserProfile({
          'first_name': firstName,
          'last_name': lastName,
          'firstName': firstName,
          'lastName': lastName,
          'name': '$firstName $lastName'.trim(),
        });
      }
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitWizard({bool isSkippingOptional = false}) async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Missing Required Info',
          message: 'Please enter your first name and surname in Step 1.',
        );
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rawPhone = isSkippingOptional ? '' : _phoneController.text.trim();
      final cleanedPhone = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
      final fullPhone = cleanedPhone.isNotEmpty ? '${_selectedCountry.dialCode}$cleanedPhone' : '';

      // Save mandatory name & surname immediately so they are never asked again
      final updatedFields = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'firstName': firstName,
        'lastName': lastName,
        'name': '$firstName $lastName'.trim(),
        'is_first_time': false,
      };

      if (!isSkippingOptional && _selectedImage != null) {
        updatedFields['avatar_url'] = _selectedImage!.path;
      }

      await ref.read(authProvider.notifier).updateUserProfile(updatedFields);

      // If user entered a phone number and is not skipping, prompt for SMS Verification Code
      if (fullPhone.isNotEmpty && !isSkippingOptional) {
        try {
          final apiClient = ref.read(apiClientProvider);
          await apiClient.post('/api/coach/send-sms-otp', data: {'phone': fullPhone});
        } catch (smsError) {
          debugPrint('[Coach Onboarding] SMS Dispatch note: $smsError');
        }

        if (mounted) {
          _showSMSVerificationModal(context, fullPhone, updatedFields);
        }
      } else {
        if (mounted) {
          AppToast.showSuccess(
            context,
            title: 'Welcome Coach!',
            message: 'Your profile has been set up successfully.',
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Setup Failed',
          message: 'Could not complete coach setup. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSMSVerificationModal(
    BuildContext context,
    String phone,
    Map<String, dynamic> baseProfile,
  ) {
    final otpController = TextEditingController();
    bool verifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (modalContext) {
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
                              'Verify SMS Code',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'SMS security code sent to $phone',
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
                            final code = otpController.text.trim();
                            if (code.length < 4) {
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
                                data: {'phone': phone, 'code': code},
                              );

                              if (res.statusCode == 200 && res.data['success'] == true) {
                                // Save verified phone number to user profile
                                final finalProfile = Map<String, dynamic>.from(baseProfile);
                                finalProfile['phone'] = phone;
                                finalProfile['phoneVerified'] = true;
                                finalProfile['phone_verified'] = true;
                                await ref.read(authProvider.notifier).updateUserProfile(finalProfile);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  AppToast.showSuccess(
                                    context,
                                    title: 'Phone Verified!',
                                    message: 'Phone number $phone verified successfully.',
                                  );
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
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
                            'Verify Code & Complete Setup',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Coach Welcome Setup',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentStep == 0 ? 'Step 1 of 2: Personal Details' : 'Step 2 of 2: Phone Number & Profile Picture',
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${((_currentStep + 1) / 2 * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003EC7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 2,
                      minHeight: 6.0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF003EC7)),
                    ),
                  ),
                ],
              ),
            ),

            // Page View Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  // STEP 1: Name & Surname
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _step1FormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 72.0,
                              height: 72.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFF003EC7).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 36.0,
                                color: Color(0xFF003EC7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          const Center(
                            child: Text(
                              'Welcome to AcademyPro',
                              style: TextStyle(
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          const Center(
                            child: Text(
                              'Let\'s get your coach profile initialized. Please enter your full name below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32.0),

                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _firstNameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name *',
                                      hintText: 'e.g. John',
                                      prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Please enter your first name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20.0),
                                  TextFormField(
                                    controller: _lastNameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Surname / Last Name *',
                                      hintText: 'e.g. Smith',
                                      prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Please enter your surname';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20.0),
                                SizedBox(width: 12.0),
                                Expanded(
                                  child: Text(
                                    'School & Team assignments are managed by your School Administrator via the Admin Portal.',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: Color(0xFF475569),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // STEP 2: Optional Contact & Avatar
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _showImagePickerModal,
                                child: CircleAvatar(
                                  radius: 48.0,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  backgroundImage: _selectedImage != null
                                      ? FileImage(File(_selectedImage!.path))
                                      : null,
                                  child: _selectedImage == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 48.0,
                                          color: Color(0xFF94A3B8),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showImagePickerModal,
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF003EC7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        const Center(
                          child: Text(
                            'Phone Number & Profile Picture',
                            style: TextStyle(
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        const Center(
                          child: Text(
                            'You can set your contact number and profile photo now, or skip and add them later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28.0),

                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    hintText: 'e.g. 82 000 0000',
                                    prefixIcon: InkWell(
                                      onTap: () {
                                        CountryCodePicker.show(
                                          context,
                                          onSelected: (code) {
                                            setState(() {
                                              _selectedCountry = code;
                                            });
                                          },
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18.0)),
                                            const SizedBox(width: 4.0),
                                            Text(
                                              _selectedCountry.dialCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.0,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 20.0),
                                            const SizedBox(width: 8.0),
                                            Container(width: 1.0, height: 20.0, color: const Color(0xFFCBD5E1)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Safe-Area Aware Action Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SafeArea(
                bottom: true,
                child: _currentStep == 0
                    ? ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50.0),
                          backgroundColor: const Color(0xFF003EC7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Continue to Step 2', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(width: 8.0),
                            Icon(Icons.arrow_forward, size: 20.0, color: Colors.white),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : () => _submitWizard(isSkippingOptional: false),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50.0),
                              backgroundColor: const Color(0xFF003EC7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20.0,
                                    width: 20.0,
                                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                  )
                                : const Text(
                                    'Finish',
                                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        _pageController.animateToPage(
                                          0,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                icon: const Icon(Icons.arrow_back, size: 16.0),
                                label: const Text('Back to Step 1'),
                              ),
                              TextButton(
                                onPressed: _isSubmitting ? null : () => _submitWizard(isSkippingOptional: true),
                                child: const Text(
                                  'Skip for Now',
                                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
