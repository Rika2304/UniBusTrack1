import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({super.key});

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'feedback': _feedbackController.text.trim(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted successfully!')),
      );
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _feedbackController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting feedback: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Feedback',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.poppins(),
                ),
                validator:
                    (val) => val!.isEmpty ? 'Please enter your name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.poppins(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator:
                    (val) => val!.isEmpty ? 'Please enter your email' : null,
              ),
              TextFormField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  labelText: 'Feedback',
                  labelStyle: GoogleFonts.poppins(),
                ),
                maxLines: 5,
                validator:
                    (val) => val!.isEmpty ? 'Please enter your feedback' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Padding(
                          padding: EdgeInsets.only(left: 20, right: 20),
                          child: Text(
                            'Submit',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
