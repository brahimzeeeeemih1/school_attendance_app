import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChildDetailsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ChildDetailsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? currentSchoolId;
  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadSchoolId();
  }

  Future<void> loadSchoolId() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

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

  Stream<QuerySnapshot> getAttendance() {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('studentId', isEqualTo: widget.studentId)
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getBehavior() {
    return FirebaseFirestore.instance
        .collection('behavior')
        .where('studentId', isEqualTo: widget.studentId)
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Color statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      default:
        return status;
    }
  }

  Color behaviorColor(String type) {
    switch (type) {
      case 'good':
        return Colors.green;
      case 'bad':
        return Colors.red;
      case 'note':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String behaviorLabel(String type) {
    switch (type) {
      case 'good':
        return 'جيد';
      case 'bad':
        return 'سيئ';
      case 'note':
        return 'ملاحظة';
      default:
        return type;
    }
  }

  List<QueryDocumentSnapshot> sortByDate(List<QueryDocumentSnapshot> docs) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aDate = '${aData['date'] ?? ''} ${aData['time'] ?? ''}';
      final bDate = '${bData['date'] ?? ''} ${bData['time'] ?? ''}';

      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  Widget attendanceTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getAttendance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = sortByDate(snapshot.data!.docs);

        if (docs.isEmpty) {
          return const Center(
            child: Text('لا يوجد سجل حضور لهذا التلميذ بعد'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final status = data['status'] ?? '';
            final date = data['date'] ?? '';
            final time = data['time'] ?? '';
            final note = data['note'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    backgroundColor: statusColor(status).withAlpha(30),
                    child: Icon(
                      status == 'absent'
                          ? Icons.cancel
                          : status == 'late'
                          ? Icons.access_time
                          : Icons.check_circle,
                      color: statusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel(status),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor(status),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('التاريخ: $date'),
                        if (time.toString().isNotEmpty) Text('الوقت: $time'),
                        if (note.toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('ملاحظة: $note'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget behaviorTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getBehavior(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = sortByDate(snapshot.data!.docs);

        if (docs.isEmpty) {
          return const Center(
            child: Text('لا يوجد سجل سلوك لهذا التلميذ بعد'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final type = data['type'] ?? '';
            final title = data['title'] ?? '';
            final description = data['description'] ?? '';
            final date = data['date'] ?? '';
            final time = data['time'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    backgroundColor: behaviorColor(type).withAlpha(30),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: behaviorColor(type),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toString().isEmpty ? 'بدون عنوان' : title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('النوع: ${behaviorLabel(type)}'),
                        Text('التاريخ: $date'),
                        if (time.toString().isNotEmpty) Text('الوقت: $time'),
                        if (description.toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text(widget.studentName),
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF101A8B),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'الحضور'),
            Tab(text: 'السلوك'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          attendanceTab(),
          behaviorTab(),
        ],
      ),
    );
  }
}