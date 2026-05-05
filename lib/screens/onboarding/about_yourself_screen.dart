import 'package:flutter/material.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'interests_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AboutYourselfScreen extends StatefulWidget {
  const AboutYourselfScreen({Key? key}) : super(key: key);

  @override
  State<AboutYourselfScreen> createState() => _AboutYourselfScreenState();
}

class _AboutYourselfScreenState extends State<AboutYourselfScreen> {
  String? _drinkingHabit;
  String? _smokingHabit;
  String? _workoutHabit;
  final List<String> _selectedPets = [];
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;


  @override
  void initState() {
    super.initState();
    // Load existing data if available
    _drinkingHabit = _onboardingData.drinkingHabit;
    _smokingHabit = _onboardingData.smokingHabit;
    _workoutHabit = _onboardingData.workoutHabit;
    _selectedPets.addAll(_onboardingData.pets);
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      // Save to onboarding data model
      _onboardingData.drinkingHabit = _drinkingHabit;
      _onboardingData.smokingHabit = _smokingHabit;
      _onboardingData.workoutHabit = _workoutHabit;
      _onboardingData.pets = _selectedPets;

      // Get current user ID
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        // Save to Supabase
        final result = await _profileService.saveLifestyle(
          userId: userId,
          drinkingHabit: _drinkingHabit,
          smokingHabit: _smokingHabit,
          workoutHabit: _workoutHabit,
          pets: _selectedPets,
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
            builder: (context) => const InterestsScreen(),
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
      backgroundColor: const Color(0xFF0D0C1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0C1E), Color(0xFF07070F)],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
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
                const SizedBox(height: 20),
                // Title
                const Text(
                  'About Yourself',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Do their habits match yours? You go first.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                // How often do you drink?
                const Text(
                  'How often do you drink?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildChip('Never', _drinkingHabit, (val) {
                      setState(() => _drinkingHabit = val);
                    }),
                    _buildChip('On special Occasionally', _drinkingHabit, (val) {
                      setState(() => _drinkingHabit = val);
                    }),
                    _buildChip('Socially on weekends', _drinkingHabit, (val) {
                      setState(() => _drinkingHabit = val);
                    }),
                    _buildChip('Most Nights', _drinkingHabit, (val) {
                      setState(() => _drinkingHabit = val);
                    }),
                  ],
                ),
                const SizedBox(height: 32),
                // How often do you smoke?
                const Text(
                  'How often do you smoke?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildChip('Non-smoker', _smokingHabit, (val) {
                      setState(() => _smokingHabit = val);
                    }),
                    _buildChip('Smoker when drinking', _smokingHabit, (val) {
                      setState(() => _smokingHabit = val);
                    }),
                    _buildChip('Social smoker', _smokingHabit, (val) {
                      setState(() => _smokingHabit = val);
                    }),
                    _buildChip('Trying to quit', _smokingHabit, (val) {
                      setState(() => _smokingHabit = val);
                    }),
                    _buildChip('Smoker', _smokingHabit, (val) {
                      setState(() => _smokingHabit = val);
                    }),
                  ],
                ),
                const SizedBox(height: 32),
                // Do you workout?
                const Text(
                  'Do you workout?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildChip('Everyday', _workoutHabit, (val) {
                      setState(() => _workoutHabit = val);
                    }),
                    _buildChip('Often', _workoutHabit, (val) {
                      setState(() => _workoutHabit = val);
                    }),
                    _buildChip('Sometimes', _workoutHabit, (val) {
                      setState(() => _workoutHabit = val);
                    }),
                    _buildChip('No, not really', _workoutHabit, (val) {
                      setState(() => _workoutHabit = val);
                    }),
                    _buildChip('No, but I plan to start', _workoutHabit, (val) {
                      setState(() => _workoutHabit = val);
                    }),
                  ],
                ),
                const SizedBox(height: 32),
                // Do you have any pets?
                const Text(
                  'Do you have any pets?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMultiSelectChip('Dog'),
                    _buildMultiSelectChip('Cat'),
                    _buildMultiSelectChip('Bird'),
                    _buildMultiSelectChip('Fish'),
                    _buildMultiSelectChip('Turtle'),
                    _buildMultiSelectChip('Hamster'),
                    _buildMultiSelectChip('Reptile'),
                    _buildMultiSelectChip('Rabbit'),
                    _buildMultiSelectChip("No, I don't have any pets"),
                  ],
                ),
                const SizedBox(height: 40),
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
      ),
      ),
    );
  }

  Widget _buildChip(String label, String? currentValue, Function(String) onSelect) {
    final isSelected = currentValue == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C3FE8) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF6C3FE8) : Colors.white24,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectChip(String label) {
    final isSelected = _selectedPets.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPets.remove(label);
          } else {
            _selectedPets.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C3FE8) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF6C3FE8) : Colors.white24,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

