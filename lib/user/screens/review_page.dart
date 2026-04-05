import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewPage extends StatefulWidget {
  final String requestId;
  final String providerId;
  final String providerName;
  final String serviceType;

  const ReviewPage({
    super.key,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final TextEditingController _reviewController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? reviewDocId;
  int rating = 5;

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color titleColor = Color(0xff284a79);

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  Future<void> _loadExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('reviews')
          .where('requestId', isEqualTo: widget.requestId)
          .get();

      if (snap.docs.isNotEmpty) {
        for (final doc in snap.docs) {
          final data = doc.data();
          if ((data['userId'] ?? '') == user.uid) {
            reviewDocId = doc.id;
            rating = (data['rating'] ?? 5) is int
                ? (data['rating'] ?? 5)
                : int.tryParse(data['rating'].toString()) ?? 5;
            _reviewController.text = data['reviewText']?.toString() ?? '';
            break;
          }
        }
      }
    } catch (_) {
      //
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewText = _reviewController.text.trim();

    if (rating < 1 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid rating')),
      );
      return;
    }

    try {
      setState(() => saving = true);

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnap.data() ?? <String, dynamic>{};

      final payload = {
        'requestId': widget.requestId,
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'userId': user.uid,
        'userName': userData['name'] ?? 'User',
        'serviceType': widget.serviceType,
        'rating': rating,
        'reviewText': reviewText,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reviewDocId == null) {
        await FirebaseFirestore.instance.collection('reviews').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('reviews')
            .doc(reviewDocId)
            .update(payload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewDocId == null
                ? 'Review submitted successfully'
                : 'Review updated successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save review: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _buildTopHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 16,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff326178), Color(0xffdff1fc)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Rate & Review',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _starButton(int value) {
    final isSelected = value <= rating;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        setState(() => rating = value);
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.star,
          size: 36,
          color: isSelected ? Colors.amber : Colors.grey.shade400,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      labelText: 'Write your review',
      hintText: 'Share your experience with this provider',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.providerName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Service: ${widget.serviceType}',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your Rating',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _starButton(1),
                      _starButton(2),
                      _starButton(3),
                      _starButton(4),
                      _starButton(5),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reviewController,
                    maxLines: 5,
                    decoration: _fieldDecoration(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: saving ? null : _saveReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff7c5ac7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        reviewDocId == null
                            ? 'Submit Review'
                            : 'Update Review',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}