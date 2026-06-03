import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Test connection on initialization
  ProfileService() {
    print('\n🔧 ProfileService initialized');
    print('🔗 Supabase connected');
    final user = _supabase.auth.currentUser;
    print('👤 Current user: ${user?.id ?? "Not authenticated"}\n');
  }

  // Save profile details (first screen after signup)
  Future<Map<String, dynamic>> saveProfileDetails({
    required String userId,
    required String firstName,
    required String lastName,
    File? profileImage,
  }) async {
    try {
      print('\n🚀 ========== SAVING PROFILE DETAILS ==========');
      print('📋 User ID: $userId');
      print('📋 First Name: $firstName');
      print('📋 Last Name: $lastName');
      print('📋 Has Image: ${profileImage != null}');

      String? profileImageUrl;

      // Upload profile image if provided
      if (profileImage != null) {
        print('\n📸 Starting image upload...');
        try {
          final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          print('📸 File name: $fileName');
          
          await _supabase.storage
              .from('profile-images')
              .upload(fileName, profileImage);
          
          print('✅ Image uploaded successfully');

          profileImageUrl = _supabase.storage
              .from('profile-images')
              .getPublicUrl(fileName);
          
          print('🔗 Image URL: $profileImageUrl');
        } catch (imageError) {
          print('❌ Image upload failed: $imageError');
          // Continue anyway, just without image
        }
      }

      // Update user profile in database
      print('\n💾 Attempting database upsert...');
      final data = {
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'profile_image_url': profileImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      print('💾 Data to insert: $data');

      final response = await _supabase
          .from('profiles')
          .upsert(data)
          .select()
          .single();

      print('✅ Database upsert successful!');
      print('📊 Response: $response');
      print('========================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ========== ERROR IN SAVE PROFILE DETAILS ==========');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error message: $e');
      print('====================================================\n');

      return {'success': false, 'error': e.toString()};
    }
  }

  // Save gender selection
  Future<Map<String, dynamic>> saveGender({
    required String userId,
    required String gender,
  }) async {
    try {
      print('\n🚀 ========== SAVING GENDER ==========');
      print('📋 User ID: $userId');
      print('📋 Gender: $gender');

      final response = await _supabase
          .from('profiles')
          .update({
            'gender': gender,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Gender saved successfully!');
      print('📊 Response: $response');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving gender: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save birthday
  Future<Map<String, dynamic>> saveBirthday({
    required String userId,
    required DateTime birthday,
  }) async {
    try {
      print('\n🚀 ========== SAVING BIRTHDAY ==========');
      print('📋 User ID: $userId');
      print('📋 Birthday: $birthday');

      // Calculate age
      final now = DateTime.now();
      var age = now.year - birthday.year;
      if (now.month < birthday.month || 
          (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      print('📋 Calculated age: $age');

      final response = await _supabase
          .from('profiles')
          .update({
            'birthday': birthday.toIso8601String(),
            'age': age,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Birthday saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving birthday: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save height
  Future<Map<String, dynamic>> saveHeight({
    required String userId,
    required int heightCm,
  }) async {
    try {
      print('\n🚀 ========== SAVING HEIGHT ==========');
      print('📋 User ID: $userId');
      print('📋 Height: $heightCm cm');

      final response = await _supabase
          .from('profiles')
          .update({
            'height_cm': heightCm,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Height saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving height: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save location
  Future<Map<String, dynamic>> saveLocation({
    required String userId,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      print('\n🚀 ========== SAVING LOCATION ==========');
      print('📋 User ID: $userId');
      print('📋 Location: $location');
      print('📋 Lat: $latitude, Lng: $longitude');

      final response = await _supabase
          .from('profiles')
          .update({
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Location saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving location: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save lifestyle/habits
  Future<Map<String, dynamic>> saveLifestyle({
    required String userId,
    String? drinkingHabit,
    String? smokingHabit,
    String? workoutHabit,
    List<String>? pets,
    String? bio,
  }) async {
    try {
      print('\n🚀 ========== SAVING LIFESTYLE ==========');
      print('📋 User ID: $userId');
      print('📋 Drinking: $drinkingHabit');
      print('📋 Smoking: $smokingHabit');
      print('📋 Workout: $workoutHabit');
      print('📋 Pets: $pets');
      print('📋 Bio: $bio');

      final payload = <String, dynamic>{
        'drinking_habit': drinkingHabit,
        'smoking_habit':  smokingHabit,
        'workout_habit':  workoutHabit,
        'pets':           pets,
        'updated_at':     DateTime.now().toIso8601String(),
      };
      if (bio != null && bio.isNotEmpty) payload['bio'] = bio;

      final response = await _supabase
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select()
          .single();

      print('✅ Lifestyle saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving lifestyle: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save interests
  Future<Map<String, dynamic>> saveInterests({
    required String userId,
    required List<String> interests,
  }) async {
    try {
      print('\n🚀 ========== SAVING INTERESTS ==========');
      print('📋 User ID: $userId');
      print('📋 Interests: $interests');

      final response = await _supabase
          .from('profiles')
          .update({
            'interests': interests,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Interests saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving interests: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Save multiple photos
  Future<Map<String, dynamic>> savePhotos({
    required String userId,
    required List<File> photos,
  }) async {
    try {
      print('\n🚀 ========== SAVING PHOTOS ==========');
      print('📋 User ID: $userId');
      print('📋 Number of photos: ${photos.length}');

      List<String> photoUrls = [];

      // Upload each photo
      for (int i = 0; i < photos.length; i++) {
        print('\n📸 Uploading photo ${i + 1}/${photos.length}...');
        final fileName = 'photo_${userId}_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await _supabase.storage
            .from('user-photos')
            .upload(fileName, photos[i]);

        final url = _supabase.storage
            .from('user-photos')
            .getPublicUrl(fileName);
        
        photoUrls.add(url);
        print('✅ Photo ${i + 1} uploaded: $url');
      }

      // Save photo URLs to database
      print('\n💾 Saving photo URLs to database...');
      final response = await _supabase
          .from('profiles')
          .update({
            'photos': photoUrls,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ All photos saved successfully!');
      print('=====================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR saving photos: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Mark profile as complete
  Future<Map<String, dynamic>> completeProfile({
    required String userId,
  }) async {
    try {
      print('\n🚀 ========== COMPLETING PROFILE ==========');
      print('📋 User ID: $userId');

      final response = await _supabase
          .from('profiles')
          .update({
            'profile_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      print('✅ Profile marked as complete!');
      print('🎉 ONBOARDING FINISHED!');
      print('==========================================\n');

      return {'success': true, 'data': response};
    } catch (e) {
      print('\n❌ ERROR completing profile: $e\n');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      print('\n🔍 Getting profile for user: $userId');
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      print('✅ Profile retrieved: $response\n');
      return response;
    } catch (e) {
      print('❌ Error getting profile: $e\n');
      return null;
    }
  }
}