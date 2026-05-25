import 'package:flutter/material.dart';

class OnboardingProgressDots extends StatelessWidget {
  final int currentStep; // which step we're on (1-based)
  static const int totalSteps = 11; // fixed — total onboarding screens

  const OnboardingProgressDots({
    Key? key,
    required this.currentStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8, // active dot is wider (pill shape)
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF7B5CFA) // purple when active
                : Colors.white24, // faded when inactive
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
