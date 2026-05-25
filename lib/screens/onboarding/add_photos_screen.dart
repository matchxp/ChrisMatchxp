import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/matchxp_background.dart';
import '../main_navigation.dart';
import 'onboarding_progress_dots.dart';
import 'location_screen.dart';

class AddPhotosScreen extends StatefulWidget {
  const AddPhotosScreen({Key? key}) : super(key: key);

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  final List<File?> _photos = List.filled(6, null);
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  int get _photoCount => _photos.where((p) => p != null).length;

  // ── Pick multiple images at once ──────────────────────────────────────────
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;

    setState(() {
      for (final image in images) {
        // Fill the next available slot
        final emptyIndex = _photos.indexWhere((p) => p == null);
        if (emptyIndex != -1) {
          _photos[emptyIndex] = File(image.path);
        }
      }
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos[index] = null);
  }

  Future<void> _saveAndComplete() async {
    if (_photoCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 photos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final photoFiles = _photos.whereType<File>().toList();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        List<String> photoUrls = [];
        for (int i = 0; i < photoFiles.length; i++) {
          final fileName =
              'photo_${userId}_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage
              .from('user-photos')
              .upload(fileName, photoFiles[i]);
          final url = Supabase.instance.client.storage
              .from('user-photos')
              .getPublicUrl(fileName);
          photoUrls.add(url);
        }

        await Supabase.instance.client.from('profiles').update({
          'photos': photoUrls,
          'profile_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LocationScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      body: MatchXPBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                // ── Back + dots ───────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: OnboardingProgressDots(currentStep: 10),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Title — centred ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: Text('Strike a pose 📸',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      )),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Time to bring your profile to life',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.80),
                    ),
                  ),
                ),

                const SizedBox(height: 100),

                // ── Photo grid — tap anywhere to pick multiple ────
                Expanded(
                  child: GestureDetector(
                    onTap: _photoCount < 6 ? _pickImages : null,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: 6,
                      itemBuilder: (_, index) => _buildPhotoBox(index),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Bottom hint ───────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _photoCount >= 2 ? _purple : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text('$_photoCount/6',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _photoCount < 2
                            ? "Hey! Let's add 2 to start. We recommend 5 (but 2 is enough). You can always add or remove more."
                            : _photoCount < 5
                                ? "Looking good! Add ${5 - _photoCount} more for best results."
                                : "Amazing! Your profile will stand out 🔥",
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Continue button ───────────────────────────────
                GestureDetector(
                  onTap: (_photoCount >= 2 && !_isSaving)
                      ? _saveAndComplete
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: (_photoCount >= 2 && !_isSaving)
                          ? const LinearGradient(colors: [_purple, _purple2])
                          : null,
                      color: (_photoCount < 2 || _isSaving)
                          ? Colors.white.withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _isSaving ? 'Completing Profile...' : 'Continue',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Photo box ─────────────────────────────────────────────────────────────
  Widget _buildPhotoBox(int index) {
    final hasPhoto = _photos[index] != null;
    final isFirst = index == 0;

    return Stack(
      children: [
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPhoto
                    ? _purple.withOpacity(0.6)
                    : _purple.withOpacity(0.30),
                width: hasPhoto ? 1.5 : 1.0,
              ),
              image: hasPhoto
                  ? DecorationImage(
                      image: FileImage(_photos[index]!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasPhoto
                ? null
                : Center(
                    child: Icon(Icons.add_photo_alternate_rounded,
                        color: _purple.withOpacity(0.5), size: 32),
                  ),
          ),
        ),

        // Main badge on first slot
        if (isFirst && hasPhoto)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purple2]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Main',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),

        // Remove button
        if (hasPhoto)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
      ],
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator({required int current, required int total}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _purple
                : isPast
                    ? _purple.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
          ),
        );
      }),
    );
  }
}
