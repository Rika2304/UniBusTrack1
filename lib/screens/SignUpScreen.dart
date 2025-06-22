import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:unibustrack/auth/auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _universityRollController =
      TextEditingController();
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _selectedRole = 'student';
  String? _selectedUniversityName;
  String? _selectedBusNo;
  int? _selectedUniversityId;

  bool _isLoading = false;
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _bus = [];

  @override
  void initState() {
    super.initState();
    _loadUniversities();
    _loadBus();
  }

  Future<void> _loadUniversities() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('university').get();
    setState(() {
      _universities = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _loadBus() async {
    final snapshot = await FirebaseFirestore.instance.collection('bus').get();
    setState(() {
      _bus = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 80,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Create Your Account",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Row(
                        children: [
                          Text(
                            "I am a: ",
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: _selectedRole,
                            items: const [
                              DropdownMenuItem(
                                value: 'student',
                                child: Text("Student"),
                              ),
                              DropdownMenuItem(
                                value: 'driver',
                                child: Text("Driver"),
                              ),
                            ],
                            onChanged:
                                (value) =>
                                    setState(() => _selectedRole = value!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(_nameController, "Full Name"),
                      _buildTextField(
                        _ageController,
                        "Age",
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        _emailController,
                        "Email",
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildTextField(
                        _phoneController,
                        "Phone Number",
                        keyboardType: TextInputType.phone,
                      ),

                      if (_selectedRole == 'student')
                        _buildTextField(
                          _universityRollController,
                          "University Roll Number",
                        ),

                      if (_selectedRole == 'driver')
                        DropdownButtonFormField<String>(
                          value: _selectedBusNo,
                          items:
                              _bus.map((bus) {
                                return DropdownMenuItem<String>(
                                  value: bus['bus_no'],
                                  child: Text(bus['bus_no']),
                                );
                              }).toList(),
                          onChanged: (value) {
                            final selected = _bus.firstWhere(
                              (b) => b['bus_no'] == value,
                            );
                            setState(() {
                              _busNumberController.text = selected['bus_no'];
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Select Bus Number',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (value) =>
                                  value == null ? 'Please select a Bus' : null,
                        ),
                      if (_selectedRole == 'driver') const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        value: _selectedUniversityName,
                        items:
                            _universities.map((uni) {
                              return DropdownMenuItem<String>(
                                value: uni['university_name'],
                                child: Text(uni['university_name']),
                              );
                            }).toList(),
                        onChanged: (value) {
                          final selected = _universities.firstWhere(
                            (u) => u['university_name'] == value,
                          );
                          setState(() {
                            _selectedUniversityName =
                                selected['university_name'];
                            _selectedUniversityId = selected['university_id'];
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Select University',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null
                                    ? 'Please select a university'
                                    : null,
                      ),

                      const SizedBox(height: 15),

                      _buildTextField(
                        _passwordController,
                        "Password",
                        obscureText: true,
                      ),
                      _buildTextField(
                        _confirmPasswordController,
                        "Confirm Password",
                        obscureText: true,
                      ),

                      const SizedBox(height: 30),

                      ElevatedButton(
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isLoading = true);

                            final message = await context
                                .read<Authentication>()
                                .signUp(
                                  name: _nameController.text.trim(),
                                  age: _ageController.text.trim(),
                                  email: _emailController.text.trim(),
                                  phone: _phoneController.text.trim(),
                                  password: _passwordController.text.trim(),
                                  universityId:
                                      _selectedUniversityId.toString(),
                                  universityName: _selectedUniversityName!,
                                  role: _selectedRole,
                                  universityRoll:
                                      _selectedRole == 'student'
                                          ? _universityRollController.text
                                              .trim()
                                          : null,
                                  busNumber:
                                      _selectedRole == 'driver'
                                          ? _busNumberController.text.trim()
                                          : null,
                                );

                            setState(() => _isLoading = false);

                            if (message == "Account created successfully") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Registration Successful!"),
                                ),
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          }
                        },
                        child: Text(
                          "Register",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (label == "Confirm Password" &&
              value != _passwordController.text) {
            return "Passwords do not match";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
