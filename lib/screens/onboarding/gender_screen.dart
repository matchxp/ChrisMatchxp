import 'package:flutter/material.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'birthday_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({Key? key}) : super(key: key);

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selectedGender;
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load existing data if available
    if (_onboardingData.gender != null) {
      _selectedGender = _onboardingData.gender;
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedGender == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save to onboarding data model
      _onboardingData.gender = _selectedGender;

      // Get current user ID
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        // Save to Supabase
        final result = await _profileService.saveGender(
          userId: userId,
          gender: _selectedGender!,
        );

        if (!result['success']) {
          throw Exception(result['error']);
        }
      }

      // Navigate to next screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BirthdayScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              // Title
              const Center(
                child: Text(
                  'I am a',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // Gender Options
              _buildGenderOption('Men', 'Men'),
              const SizedBox(height: 16),
              _buildGenderOption('Women', 'Women'),
              const SizedBox(height: 16),
              _buildGenderOption('Other', 'Other'),
              const Spacer(),
              // Continue Button
              CustomButton(
                text: _isSaving ? 'Saving...' : 'Continue',
                onPressed: (_selectedGender != null && !_isSaving)
                    ? _saveAndContinue
                    : null,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String label, String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF6C3FE8) : Colors.white24,
            width: isSelected ? 2.0 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFF6C3FE8),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}