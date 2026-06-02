import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home/home_page.dart';
import 'login_page.dart';
import 'complete_profile_page.dart';

/// Listens to [FirebaseAuth] and shows the next required screen.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Auth state error: ${snapshot.error}')),
          );
        }
        if (snapshot.hasData) {
          final User user = snapshot.data!;
          if ((user.displayName ?? '').trim().isEmpty) {
            return const CompleteProfilePage();
          }
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
