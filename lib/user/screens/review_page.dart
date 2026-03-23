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
      // keep page usable even if lookup fails
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

  Widget _starButton(int value) {
    final isSelected = value <= rating;

    return IconButton(
      onPressed: () {
        setState(() => rating = value);
      },
      icon: Icon(
        Icons.star,
        size: 34,
        color: isSelected ? Colors.amber : Colors.grey,
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
      appBar: AppBar(
        title: const Text('Rate & Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 20),
            const Text(
              'Your Rating',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Write your review',
                hintText: 'Share your experience with this provider',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _saveReview,
                child: saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(reviewDocId == null ? 'Submit Review' : 'Update Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}