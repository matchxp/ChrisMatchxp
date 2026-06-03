import 'dart:io';

class OnboardingData {
  // Profile Details
  String? firstName;
  String? lastName;
  File? profileImage;

  // Gender
  String? gender;

  // Birthday
  DateTime? birthday;

  // Height
  int? heightCm;

  // Location
  String? location;
  double? latitude;
  double? longitude;

  // Lifestyle
  String? drinkingHabit;
  String? smokingHabit;
  String? workoutHabit;
  List<String> pets = [];
  String? bio;

  //Lookign for//
  String? lookingFor;

  //connectwith//
  List<String> connectWith = [];

  // Interests
  List<String> interests = [];

  //values//
  String? zodiac;
  List<String> religion = [];

  // Photos
  List<File> photos = [];

  // Singleton pattern
  static final OnboardingData _instance = OnboardingData._internal();

  factory OnboardingData() {
    return _instance;
  }

  OnboardingData._internal();

  // Clear all data
  void clear() {
    firstName = null;
    lastName = null;
    profileImage = null;
    gender = null;
    birthday = null;
    heightCm = null;
    location = null;
    latitude = null;
    longitude = null;
    drinkingHabit = null;
    smokingHabit = null;
    workoutHabit = null;
    pets.clear();
    bio = null;
    lookingFor = null;
    connectWith.clear();
    interests.clear();
    zodiac = null;
    religion.clear();
    photos.clear();
  }

  // Check if profile is complete
  bool get isComplete {
    return firstName != null &&
        lastName != null &&
        gender != null &&
        birthday != null &&
        heightCm != null &&
        location != null &&
        photos.length >= 2;
  }

  // Get completion percentage
  double get completionPercentage {
    int completed = 0;
    int total = 8;

    if (firstName != null && lastName != null) completed++;
    if (gender != null) completed++;
    if (birthday != null) completed++;
    if (heightCm != null) completed++;
    if (location != null) completed++;
    if (drinkingHabit != null || smokingHabit != null || workoutHabit != null) {
      completed++;
    }
    if (interests.isNotEmpty) completed++;
    if (photos.length >= 2) completed++;

    return completed / total;
  }
}
