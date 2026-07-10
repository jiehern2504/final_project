import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/profile_constants.dart';
import '../summary/summary_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  String _selectedGender = kGenderOptions.first;
  String _selectedActivity = kActivityOptions.first;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  int? _parseWholeNumber(
    String raw, {
    required String fieldName,
    required int min,
    required int max,
  }) {
    final String input = raw.trim();
    if (input.isEmpty) {
      _showError('$fieldName is required');
      return null;
    }
    final int? value = int.tryParse(input);
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

  double? _parseNumeric(
    String raw, {
    required String fieldName,
    required double min,
    required double max,
  }) {
    final String input = raw.trim();
    if (input.isEmpty) {
      _showError('$fieldName is required');
      return null;
    }
    final double? value = double.tryParse(input);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _readDouble(Map<String, dynamic> data, String key) {
    final dynamic raw = data[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  String _readOption(
    Map<String, dynamic> data,
    String key,
    List<String> options,
    String fallback,
  ) {
    final dynamic raw = data[key];
    if (raw is String && options.contains(raw)) return raw;
    return fallback;
  }

  int? _readInt(Map<String, dynamic> data, String key) {
    final dynamic raw = data[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _readText(Map<String, dynamic> data, String key) {
    final dynamic raw = data[key];
    if (raw is String) return raw.trim();
    return '';
  }

  Future<void> saveData() async {
    if (_isSaving || _isLoading) return;
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;
    if (uid == null || user == null) {
      _showError('You are not signed in.');
      return;
    }
    final String firstName = firstNameController.text.trim();
    final String lastName = lastNameController.text.trim();
    if (firstName.isEmpty) {
      _showError('First name is required');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Last name is required');
      return;
    }
    final int? age = _parseWholeNumber(
      ageController.text,
      fieldName: 'Age',
      min: 12,
      max: 100,
    );
    if (age == null) return;
    final double? height = _parseNumeric(
      heightController.text,
      fieldName: 'Height (cm)',
      min: 80,
      max: 260,
    );
    if (height == null) return;
    final double? weight = _parseNumeric(
      weightController.text,
      fieldName: 'Weight (kg)',
      min: 25,
      max: 350,
    );
    if (weight == null) return;

    setState(() => _isSaving = true);
    try {
      await user.updateDisplayName('$firstName $lastName');
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': _selectedGender,
        'activityLevel': _selectedActivity,
        // Reset the anchor for yearly age auto-increment (see AgeUpdater).
        'ageSetAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Log the weight so the Home summary chart has a data point.
      await SummaryRepository().logWeight(weight);
      _showSuccess('Profile saved. The new changes will show on next login');
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Failed to save profile data.');
    } catch (_) {
      _showError('Something went wrong while saving profile data.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> loadData() async {
    setState(() => _isLoading = true);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      _showError('You are not signed in.');
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final String firstName = _readText(data, 'firstName');
      final String lastName = _readText(data, 'lastName');
      final int? age = _readInt(data, 'age');
      final double? height = _readDouble(data, 'height');
      final double? weight = _readDouble(data, 'weight');
      final String gender = _readOption(
        data,
        'gender',
        kGenderOptions,
        kGenderOptions.first,
      );
      final String activity = _readOption(
        data,
        'activityLevel',
        kActivityOptions,
        kActivityOptions.first,
      );

      if (!mounted) return;
      setState(() {
        firstNameController.text = firstName;
        lastNameController.text = lastName;
        ageController.text = age?.toString() ?? '';
        heightController.text = height?.toString() ?? '';
        weightController.text = weight?.toString() ?? '';
        _selectedGender = gender;
        _selectedActivity = activity;
      });
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Failed to load profile data.');
    } catch (_) {
      _showError('Something went wrong while loading profile data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to sign out.');
    } catch (_) {
      _showError('Something went wrong while signing out.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Profile"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _isLoading
                        ? const <Widget>[
                            SizedBox(height: 24),
                            Center(child: CircularProgressIndicator()),
                            SizedBox(height: 12),
                          ]
                        : <Widget>[
                            Text(
                              "Personal Information",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Keep your profile accurate for better plan recommendations.",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.black54),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: firstNameController,
                              decoration: const InputDecoration(
                                labelText: "First Name",
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: lastNameController,
                              decoration: const InputDecoration(
                                labelText: "Last Name",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: ageController,
                              decoration: const InputDecoration(
                                labelText: "Age",
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: heightController,
                              decoration: const InputDecoration(
                                labelText: "Height (cm)",
                                prefixIcon: Icon(Icons.height),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: weightController,
                              decoration: const InputDecoration(
                                labelText: "Weight (kg)",
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey<String>('gender_$_selectedGender'),
                              initialValue: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: "Gender",
                                prefixIcon: Icon(Icons.person_outline),
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
                              key: ValueKey<String>(
                                'activity_$_selectedActivity',
                              ),
                              initialValue: _selectedActivity,
                              decoration: const InputDecoration(
                                labelText: "Activity Level",
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
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : saveData,
                              icon: const Icon(Icons.save_outlined),
                              label: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Save Profile"),
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
