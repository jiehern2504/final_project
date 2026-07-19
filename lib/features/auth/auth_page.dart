import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home/home_page.dart';
import '../onboarding/onboarding_flow_page.dart';
import 'login_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Auth state error: ${snapshot.error}')),
          );
        }
        final User? user = snapshot.data;
        if (user == null) return const LoginPage();
        return _ProfileGate(uid: user.uid);
      },
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingScaffold();
        }
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};
        final bool profileComplete =
            data['height'] != null && data['weight'] != null;
        return profileComplete ? const HomePage() : const OnboardingFlowPage();
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
