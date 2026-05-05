import 'package:flutter/material.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'location_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HeightScreen extends StatefulWidget {
  const HeightScreen({Key? key}) : super(key: key);

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  double _heightCm = 170.0;
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;
  
  int get feet => (_heightCm / 30.48).floor();
  int get inches => (((_heightCm / 30.48) - feet) * 12).round();

  @override
  void initState() {
    super.initState();
    if (_onboardingData.heightCm != null) {
      _heightCm = _onboardingData.heightCm!.toDouble();
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      _onboardingData.heightCm = _heightCm.toInt();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        final result = await _profileService.saveHeight(
          userId: userId,
          heightCm: _heightCm.toInt(),
        );

        if (!result['success']) {
          throw Exception(result['error']);
        }
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LocationScreen()),
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
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "What's your\nHeight?",
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
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$feet',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C3FE8),
                            height: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, left: 4, right: 8),
                          child: Text(
                            'ft',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Text(
                          '$inches',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C3FE8),
                            height: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, left: 4),
                          child: Text(
                            'in',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_heightCm.toInt()} cm',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              SizedBox(
                height: 120,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 3,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C3FE8),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3FE8).withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          setState(() {
                            final scrollOffset = notification.metrics.pixels;
                            _heightCm = 120.0 + (scrollOffset / 5);
                            _heightCm = _heightCm.clamp(120.0, 220.0);
                          });
                        }
                        return true;
                      },
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        controller: ScrollController(
                          initialScrollOffset: (_heightCm - 120.0) * 5,
                        ),
                        itemCount: 101,
                        itemBuilder: (context, index) {
                          final height = 120 + index;
                          final isSelected = height == _heightCm.toInt();
                          final isMajorMark = height % 10 == 0;
                          final isMinorMark = height % 5 == 0;
                          
                          return Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2,
                                  height: isMajorMark ? 60 : isMinorMark ? 40 : 25,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6C3FE8)
                                        : isMajorMark
                                            ? Colors.white
                                            : Colors.white38,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                if (isMajorMark)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '$height',
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF6C3FE8)
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Slide to adjust your height',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
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
}