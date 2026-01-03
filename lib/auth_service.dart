import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  /// Default behavior uses FirebaseAuth.instance
  /// Tests can inject a mock FirebaseAuth
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Creates a new user in Firebase Auth and sends them a password reset email.
  ///
  /// This is designed for a coach creating a swimmer account.
  ///
  /// IMPORTANT: Calling `createUserWithEmailAndPassword` has a significant side effect:
  /// it signs out the currently authenticated user (the coach) and signs in the
  /// newly created user. The UI calling this method is responsible for
  /// re-authenticating the coach after this operation completes.
  ///
  /// The robust, long-term solution is to create a Cloud Function using the
  /// Firebase Admin SDK to create users, which does not affect the current
  /// user's authentication state.
  ///
  /// Returns the created `User` object on success, or `null` on failure.
  Future<User?> createSwimmerAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 1. Create the user account in Firebase Auth.
      final userCredential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // 2. Update the new user's profile with their display name.
      await user.updateDisplayName(displayName);

      // 3. Send password reset email (invitation flow).
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already in use by another account.');
      } else if (e.code == 'weak-password') {
        throw Exception('The password is too weak.');
      }
      rethrow;
    }
  }
}
