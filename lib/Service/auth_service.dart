import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to handle user signup
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // Basic validation
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        return 'Please fill all fields';
      }

      // Email validation
      if (!email.contains('@')) {
        return 'Invalid email format';
      }

      // Password validation
      if (password.length < 6) {
        return 'Password must be at least 6 characters';
      }

      // Create user in Firebase Authentication with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Save additional user data (name, role) in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role, // Role determines if user is Admin or User
      });

      return null; // Success: no error message
    } catch (e) {
      return e.toString(); // Error: return the exception message
    }
  }

  // Function to handle user login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return 'Please fill all fields';
      }

      if (!email.contains('@')) {
        return 'Invalid email format';
      }

      // Sign in the user using Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Check if user exists
      if (userCredential.user == null) {
        return 'User not found';
      }

      // Fetch the user's role from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        return 'User data not found';
      }

      return userDoc.get('role') as String; // Explicitly cast to String
    } catch (e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            return 'No user found for that email';
          case 'wrong-password':
            return 'Wrong password provided';
          case 'invalid-email':
            return 'Invalid email address';
          default:
            return e.message ?? 'An error occurred';
        }
      }
      return e.toString();
    }
  }

  // Function for user log out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create credentials with the old password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );

    try {
      // Reauthenticate user
      await user.reauthenticateWithCredential(credential);
      // Update password
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }
}
