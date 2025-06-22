import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unibustrack/auth/auth.dart'; // Update if your path is different

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final Authentication _auth = Authentication(FirebaseAuth.instance);

  bool _loading = false;
  String? _message;

  Future<void> _resetPassword() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final result = await _auth.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    setState(() {
      _loading = false;
      _message = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: const Color(0xFFEFF3F6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              "Enter your email to receive a password reset link.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _resetPassword,
                  child: Text(
                    "Send Reset Link",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(
                  color:
                      _message!.toLowerCase().contains("sent")
                          ? Colors.green
                          : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
