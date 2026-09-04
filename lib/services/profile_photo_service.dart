import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../app_settings.dart';

class ProfilePhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Returns the current profile photo URL from local cache, Firebase Auth, or null.
  static String? get currentPhotoUrl {
    if (AppSettings.profilePhotoUrl != null &&
        AppSettings.profilePhotoUrl!.isNotEmpty) {
      return AppSettings.profilePhotoUrl;
    }
    try {
      return FirebaseAuth.instance.currentUser?.photoURL;
    } catch (_) {
      return null;
    }
  }

  /// Refreshes and loads the photo URL from Firestore users/{uid} collection.
  static Future<String?> fetchPhotoUrl() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return currentPhotoUrl;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final url = doc.data()?['photoUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          await AppSettings.saveProfilePhoto(url);
          return url;
        }
      }
    } catch (e) {
      developer.log('Warning fetching user photoUrl: $e');
    }

    return currentPhotoUrl;
  }

  /// Picks an image from [source], uploads it to Firebase Storage under
  /// UID-scoped path `profile-photos/{uid}/avatar.jpg`, and updates user records.
  static Future<String?> pickAndUploadPhoto({
    required ImageSource source,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to update profile photo.');
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      // User cancelled picker
      return null;
    }

    final Uint8List bytes = await pickedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Picked image file is empty.');
    }

    String? photoUrl;

    // 1. Try Firebase Storage
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile-photos')
          .child(user.uid)
          .child('avatar.jpg');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uid': user.uid},
      );

      final uploadTask = await storageRef.putData(bytes, metadata);
      photoUrl = await uploadTask.ref.getDownloadURL();
    } catch (storageError) {
      developer.log(
        'Firebase Storage not available or bucket not configured ($storageError). '
        'Falling back to high-efficiency data URI.',
      );
      // Fallback: Embed as compressed base64 JPEG data URI
      final base64String = base64Encode(bytes);
      photoUrl = 'data:image/jpeg;base64,$base64String';
    }

    // 2. Persist to AppSettings cache
    await AppSettings.saveProfilePhoto(photoUrl);

    // 3. Update Firebase Auth profile
    try {
      if (!photoUrl.startsWith('data:')) {
        await user.updatePhotoURL(photoUrl);
      }
    } catch (authErr) {
      developer.log('Warning updating FirebaseAuth photoURL: $authErr');
    }

    // 4. Update Firestore user document
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (dbErr) {
      developer.log('Warning updating Firestore users collection: $dbErr');
    }

    // 5. Update Faculty profile if applicable
    if (AppSettings.facultyId != null && AppSettings.facultyId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('faculty_profiles')
            .doc(AppSettings.facultyId)
            .set({
              'photoUrl': photoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (facultyErr) {
        developer.log('Warning updating faculty_profiles: $facultyErr');
      }
    }

    return photoUrl;
  }

  /// Removes the user's profile photo from storage, Firestore, and local settings.
  static Future<void> removePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    final current = AppSettings.profilePhotoUrl;

    // 1. Delete from Firebase Storage if it was a remote URL
    if (current != null && current.startsWith('http')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(current);
        await ref.delete();
      } catch (e) {
        developer.log('Warning deleting photo from Firebase Storage: $e');
      }
    }

    // 2. Clear AppSettings
    await AppSettings.clearProfilePhoto();

    // 3. Clear Firebase Auth photoURL
    if (user != null) {
      try {
        await user.updatePhotoURL(null);
      } catch (_) {}

      // 4. Update Firestore user doc
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'photoUrl': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        developer.log('Warning clearing Firestore photoUrl: $e');
      }
    }

    // 5. Update Faculty doc if applicable
    if (AppSettings.facultyId != null && AppSettings.facultyId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('faculty_profiles')
            .doc(AppSettings.facultyId)
            .update({
              'photoUrl': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
  }
}
