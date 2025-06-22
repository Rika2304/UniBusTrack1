import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unibustrack/utils/sharedpreference.dart';

class Authentication {
  final FirebaseAuth _firebaseAuth;
  Authentication(this._firebaseAuth);

  Stream<User?> get authStateChange => _firebaseAuth.authStateChanges();

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return "Signed In";
    } on FirebaseAuthException catch (e) {
      return e.message.toString();
    }
  }

  Future<bool> handleGoogleSignIn() async {
    final user = await GoogleSignIn().signIn();
    GoogleSignInAuthentication userAuth = await user!.authentication;
    var credential = GoogleAuthProvider.credential(
      idToken: userAuth.idToken,
      accessToken: userAuth.accessToken,
    );
    await _firebaseAuth.signInWithCredential(credential);

    return FirebaseAuth.instance.currentUser != null;
  }

  Future<String> signUp({
    required String name,
    required String age,
    required String email,
    required String phone,
    required String password,
    required String universityId,
    required String universityName,
    required String role, // 'student' or 'driver'
    String? universityRoll, // for students
    String? busNumber, // for drivers
  }) async {
    try {
      // Get FCM token from shared preferences
      final fcmToken = await getFcmToken();

      // Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'name': name,
            'email': email,
            'phone': phone,
            'age': age,
            'role': role,
            'university_id': universityId,
            'university_name': universityName,
            'university_roll': role == 'student' ? universityRoll : null,
            'bus_number': role == 'driver' ? busNumber : null,
            'fcm_token': fcmToken,
            'created_at': FieldValue.serverTimestamp(),
          });

      return "Account created successfully";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Something went wrong";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return "Password reset link sent to $email";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Failed to send reset email";
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
