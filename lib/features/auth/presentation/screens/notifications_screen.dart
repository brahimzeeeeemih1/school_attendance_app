import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? currentSchoolId;
  bool pageLoading = true;

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    loadSchoolId();
  }

  Future<void> loadSchoolId() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      setState(() {
        currentSchoolId = userDoc.data()?['schoolId'];
        pageLoading = false;
      });
    } catch (e) {
      setState(() => pageLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل schoolId: $e')),
      );
    }
  }

  Stream<QuerySnapshot> getMyNotifications() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUid)
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'بدون وقت';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();

      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');

      return '$y-$m-$d $hh:$mm';
    }

    return timestamp.toString();
  }

  List<QueryDocumentSnapshot> sortNotifications(List<QueryDocumentSnapshot> docs) {
    final sorted = [...docs];

    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aTime = aData['createdAt'];
      final bTime = bData['createdAt'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }

      return 0;
    });

    return sorted;
  }

  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (pageLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getMyNotifications(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = sortNotifications(snapshot.data!.docs);

          if (docs.isEmpty) {
            return const Center(
              child: Text('لا توجد إشعارات حتى الآن'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? '';
              final body = data['body'] ?? '';
              final studentName = data['studentName'] ?? '';
              final type = data['type'] ?? '';
              final createdAt = data['createdAt'];
              final isRead = data['isRead'] ?? false;

              final isAbsent = type == 'attendance_absent';

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (!isRead) {
                    markAsRead(doc.id);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead
                          ? Colors.transparent
                          : const Color(0xFF101A8B).withAlpha(70),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor:
                        (isAbsent ? Colors.red : Colors.blue).withAlpha(25),
                        child: Icon(
                          isAbsent
                              ? Icons.notifications_active
                              : Icons.info_outline,
                          color: isAbsent ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (studentName.toString().isNotEmpty)
                              Text('التلميذ: $studentName'),
                            const SizedBox(height: 4),
                            Text(body),
                            const SizedBox(height: 8),
                            Text(
                              'الوقت: ${formatTimestamp(createdAt)}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'جديد',
                                style: TextStyle(
                                  color: Color(0xFF101A8B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}