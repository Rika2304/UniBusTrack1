import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unibustrack/screens/HomeScreen.dart';
import 'package:unibustrack/screens/SignInScreen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    if (firebaseUser != null) {
      print(firebaseUser);
      return HomeScreen();
    } else {
      print("Null");
      return SignInScreen();
    }
  }
}
