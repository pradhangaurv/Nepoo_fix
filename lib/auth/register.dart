import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final numberController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String role = "user";
  bool loading = false;

  static const Color primary = Color(0xff326178);

  Future<void> registration() async {
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final phone = numberController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty ||
        address.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final isProvider = role == "provider";

      await _db.collection("users").doc(cred.user!.uid).set({
        "name": name,
        "address": address,
        "phone": phone,
        "email": email,
        "role": role,
        "approved": !isProvider,
        "setupComplete": !isProvider,
        "serviceType": null,
        "serviceDescription": null,
        "pricePerHour": null,
        "blocked": false,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isProvider
                ? "Provider account created. Waiting for admin approval."
                : "Account created successfully!",
          ),
        ),
      );

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyLogin()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth error: ${e.message ?? e.code}")),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firestore error: ${e.message ?? e.code}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unknown error: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    numberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black54,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.90),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  Widget _field(
      TextEditingController c,
      String hint, {
        TextInputType keyboard = TextInputType.text,
        bool obscure = false,
      }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      decoration: _fieldDecoration(hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/Assets/images/img_1.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.15,
              left: 40,
              right: 40,
            ),
            child: Column(
              children: [
                const Text(
                  "Create an Account",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: role,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  items: const [
                    DropdownMenuItem(value: "user", child: Text("User")),
                    DropdownMenuItem(
                      value: "provider",
                      child: Text("Service Provider"),
                    ),
                  ],
                  onChanged: (v) => setState(() => role = v ?? "user"),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.90),
                    labelText: "Register As",
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: primary, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(nameController, "Enter your name"),
                const SizedBox(height: 12),
                _field(addressController, "Enter your address"),
                const SizedBox(height: 12),
                _field(
                  numberController,
                  "Enter your contact number",
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  emailController,
                  "Enter your email",
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _field(
                  passwordController,
                  "Enter your password",
                  obscure: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : registration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text("Register Account"),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MyLogin()),
                      ),
                      child: const Text(
                        "Log In Now!",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}