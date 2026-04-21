import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../services/image_compression_service.dart';
import '../../services/onboarding_validator.dart';
import '../../services/profile_service.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _picker = ImagePicker();
  final _compressionService = ImageCompressionService();

  static const List<String> _genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  static const List<String> _styleOptions = [
    'Minimal',
    'Clean Drip',
    'Street Flex',
    'Soft Life',
    'Formal',
    'Casual',
  ];

  String? _gender;
  DateTime? _birthdate;
  final Set<String> _selectedStyles = <String>{};
  Uint8List? _profileBytes;
  bool _isSaving = false;

  String get _fullName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return '$first $last'.trim();
  }

  String get _displayName {
    final nickname = _nicknameController.text.trim();
    return nickname.isEmpty ? _fullName : nickname;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year - 13, 12, 31),
      helpText: 'Select Birth Year',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _birthdate = picked);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final permissionGranted = await _requestImagePermission(source);
      if (!permissionGranted) {
        _showMessage(
          source == ImageSource.camera
              ? 'Camera access was denied. Enable permission in settings to continue.'
              : 'Gallery access was denied. Enable permission in settings to continue.',
        );
        return;
      }

      final image = await _picker.pickImage(source: source, imageQuality: 90);
      if (image == null) return;

      // Crop to a square — user can adjust/skip crop.
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      // User cancelled crop — keep previous image unchanged.
      if (cropped == null) return;

      final bytes = await cropped.readAsBytes();
      final compressed = await _compressionService.compressBytes(
        bytes,
        maxWidth: 500,
        jpegQuality: 72,
      );

      setState(() => _profileBytes = compressed.bytes);
    } catch (_) {
      _showMessage('Unable to process selected image. Please try again.');
    }
  }

  Future<bool> _requestImagePermission(ImageSource source) async {
    if (kIsWeb) return true;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }

    try {
      final photos = await Permission.photos.request();
      if (photos.isGranted) return true;
    } catch (_) {
      // Fall back to storage permission on Android and older API levels.
    }

    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> _submit() async {
    final validation = OnboardingValidator.validate(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      gender: _gender,
      birthdate: _birthdate,
      stylePreferences: _selectedStyles.toList(),
    );
    if (validation != null) {
      _showMessage(validation);
      return;
    }

    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) {
      _showMessage('Your session expired. Please sign in again.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profileService = context.read<ProfileService>();
      final age = OnboardingValidator.calculateAge(_birthdate!);

      // Profile photo is optional — upload only when the user chose one.
      String imageUrl = '';
      if (_profileBytes != null) {
        imageUrl = await profileService.uploadProfileImage(
          userId: user.uid,
          imageBytes: _profileBytes!,
        );
      }

      await profileService.saveOnboardingProfile(
        userId: user.uid,
        email: user.email ?? '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        displayName: _displayName,
        gender: _gender!,
        birthdate: _birthdate!,
        age: age,
        stylePreferences: _selectedStyles.toList(),
        profileImageUrl: imageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      );
    } catch (e) {
      _showMessage('Could not save your profile right now. Please retry.');
      debugPrint('[Onboarding] saveProfile error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Style Onboarding',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us who you are so DLS can personalize your wardrobe journey.',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        hintText: 'First name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        hintText: 'Last name',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nicknameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display Name / Nickname',
                  hintText: 'What should we call you? (optional)',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender *',
                ),
                items: _genders
                    .map(
                      (g) => DropdownMenuItem<String>(
                        value: g,
                        child: Text(g),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickBirthYear,
                borderRadius: BorderRadius.circular(18),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Birth Year *',
                  ),
                  child: Text(
                    _birthdate == null
                        ? 'Select year'
                        : '${_birthdate!.year} (Age ${OnboardingValidator.calculateAge(_birthdate!)})',
                    style: const TextStyle(color: AppTheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Style Preferences *',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _styleOptions
                    .map(
                      (option) => FilterChip(
                        label: Text(option),
                        selected: _selectedStyles.contains(option),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStyles.add(option);
                            } else {
                              _selectedStyles.remove(option);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Profile Photo (optional)',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _profileBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap below to add a photo',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can also skip this step',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(_profileBytes!, fit: BoxFit.cover, width: double.infinity),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _profileBytes = null),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _pickProfileImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _pickProfileImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Complete Onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
