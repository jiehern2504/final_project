import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/profile_constants.dart';
import 'auth_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});
  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}
class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String _selectedGender = kGenderOptions.first;
  String _selectedActivity = kActivityOptions.first;
  bool _isSaving = false;
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  int? _parseInt(
      String raw, {
        required String fieldName,
        required int min,
        required int max,
      }) {
    final int? value = int.tryParse(raw.trim());
    if (value == null) {
      _showError('$fieldName must be a valid number');
      return null;
    }
    if (value < min || value > max) {
      _showError('$fieldName must be between $min and $max');
      return null;
    }
    return value;
  }

  double? _parseDouble(
      String raw, {
        required String fieldName,
        required double min,
        required double max,
      }) {
    final double? value = double.tryParse(raw.trim());
    if (value == null) {
      _showError('$fieldName must be a valid number');
      return null;
    }
    if (value < min || value > max) {
      _showError('$fieldName must be between $min and $max');
      return null;
    }
    return value;
  }
  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You are not signed in.');
      return;
    }
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) {
      _showError('First name is required');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Last name is required');
      return;
    }

    final int? age = _parseInt(
      _ageController.text,
      fieldName: 'Age',
      min: 12,
      max: 100,
    );
    if (age == null) return;
    final double? height = _parseDouble(
      _heightController.text,
      fieldName: 'Height (cm)',
      min: 80,
      max: 260,
    );
    if (height == null) return;
    final double? weight = _parseDouble(
      _weightController.text,
      fieldName: 'Weight (kg)',
      min: 25,
      max: 350,
    );
    if (weight == null) return;

    setState(() => _isSaving = true);
    try {
      final String displayName = '$firstName $lastName';
      await user.updateDisplayName(displayName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': _selectedGender,
        'activityLevel': _selectedActivity,
      }, SetOptions(merge: true));
      await user.reload();
      if (!mounted) return;
      // Rebuild from `AuthPage` so it immediately shows HomePage.
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const AuthPage(),
        ),
            (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to update your account.');
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Failed to save your profile.');
    } catch (_) {
      _showError('Something went wrong while saving your profile.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tell us a little about you',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'We will use these details for your beginner workout experience.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          prefixIcon: Icon(Icons.height),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: kGenderOptions
                            .map(
                              (String item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          setState(() => _selectedGender = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedActivity,
                        decoration: const InputDecoration(
                          labelText: 'Activity Level',
                          prefixIcon: Icon(Icons.directions_run),
                        ),
                        items: kActivityOptions
                            .map(
                              (String item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          setState(() => _selectedActivity = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save and Continue'),
                        ),
                      ),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
