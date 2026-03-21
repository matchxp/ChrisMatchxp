import 'package:flutter/material.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'height_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({Key? key}) : super(key: key);

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load existing data if available
    if (_onboardingData.birthday != null) {
      _dayController.text = _onboardingData.birthday!.day.toString().padLeft(2, '0');
      _monthController.text = _onboardingData.birthday!.month.toString().padLeft(2, '0');
      _yearController.text = _onboardingData.birthday!.year.toString();
    }
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    // Validate input
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);

    if (day == null || month == null || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (day < 1 || day > 31 || month < 1 || month > 12 || year < 1900 || year > DateTime.now().year) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is at least 18 years old
    final birthday = DateTime(year, month, day);
    final now = DateTime.now();
    var age = now.year - birthday.year;
    if (now.month < birthday.month || 
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save to onboarding data model
      _onboardingData.birthday = birthday;

      // Get current user ID
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        // Save to Supabase
        final result = await _profileService.saveBirthday(
          userId: userId,
          birthday: birthday,
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
            builder: (context) => const HeightScreen(),
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
                  'When is your\nbirthday?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // Birthday Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDateField(_dayController, 'DD', 2),
                  const SizedBox(width: 12),
                  _buildDateField(_monthController, 'MM', 2),
                  const SizedBox(width: 12),
                  _buildDateField(_yearController, 'YYYY', 4),
                ],
              ),
              const Spacer(),
              // Continue Button
              CustomButton(
                text: _isSaving ? 'Saving...' : 'Continue',
                onPressed: _isSaving ? null : _saveAndContinue,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String hint,
    int maxLength,
  ) {
    return Container(
      width: hint == 'YYYY' ? 100 : 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF6C3FE8), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: maxLength,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}