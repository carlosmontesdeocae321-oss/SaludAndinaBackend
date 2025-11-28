import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "164717464166-ftmd4dvtgih0qgi414phq6udis11tjlg.apps.googleusercontent.com",
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      print("Error Google Sign-In: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
