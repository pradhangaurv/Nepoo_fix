import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendPasswordResetEmail() async {
    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;  // Ensure widget is still mounted before accessing context
      setState(() {
        _isLoading = false;
      });

      // Show confirmation
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
      Navigator.pop(context); // Go back to the previous screen (login)
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      backgroundColor: Colors.white,  // Set background color to white
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email TextField for password reset
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address/User Name',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // Send Reset Link Button
            ElevatedButton(
              onPressed: _isLoading ? null : _sendPasswordResetEmail,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }
}