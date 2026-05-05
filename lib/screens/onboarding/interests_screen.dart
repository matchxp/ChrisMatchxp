import 'package:flutter/material.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'add_photos_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({Key? key}) : super(key: key);

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final List<String> _selectedInterests = [];
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;
  
  final List<Map<String, dynamic>> _interests = [
    {'icon': Icons.camera_alt, 'label': 'Photography'},
    {'icon': Icons.restaurant, 'label': 'Cooking'},
    {'icon': Icons.videogame_asset, 'label': 'Video Games'},
    {'icon': Icons.music_note, 'label': 'Music'},
    {'icon': Icons.flight, 'label': 'Travelling'},
    {'icon': Icons.shopping_bag, 'label': 'Shopping'},
    {'icon': Icons.mic, 'label': 'Speeches'},
    {'icon': Icons.palette, 'label': 'Art & Crafts'},
    {'icon': Icons.pool, 'label': 'Swimming'},
    {'icon': Icons.local_bar, 'label': 'Drinking'},
    {'icon': Icons.sports_basketball, 'label': 'Extreme Sports'},
    {'icon': Icons.fitness_center, 'label': 'Fitness'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterests.addAll(_onboardingData.interests);
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      _onboardingData.interests = _selectedInterests;
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        final result = await _profileService.saveInterests(
          userId: userId,
          interests: _selectedInterests,
        );

        if (!result['success']) {
          throw Exception(result['error']);
        }
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPhotosScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              const Text(
                'Likes, Interests',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share your likes & passion with others',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _interests.length,
                  itemBuilder: (context, index) {
                    final interest = _interests[index];
                    final isSelected = _selectedInterests.contains(interest['label']);
                    return _buildInterestCard(
                      icon: interest['icon'],
                      label: interest['label'],
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedInterests.remove(interest['label']);
                          } else {
                            _selectedInterests.add(interest['label']);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
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
    );
  }

  Widget _buildInterestCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF6C3FE8).withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF6C3FE8) : Colors.white24,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6C3FE8) : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}