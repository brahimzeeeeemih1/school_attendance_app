import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? currentSchoolId;
  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    loadSchoolId();
  }

  Future<void> loadSchoolId() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      setState(() {
        currentSchoolId = userDoc.data()?['schoolId'];
        pageLoading = false;
      });
    } catch (e) {
      setState(() {
        pageLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل schoolId: $e')),
      );
    }
  }

  Stream<QuerySnapshot> getStudents() {
    return FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getTeachers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getParents() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getClasses() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getAttendance() {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getBehavior() {
    return FirebaseFirestore.instance
        .collection('behavior')
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  int countAttendanceByStatus(List<QueryDocumentSnapshot> docs, String status) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == status;
    }).length;
  }

  int countBehaviorByType(List<QueryDocumentSnapshot> docs, String type) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['type'] == type;
    }).length;
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withAlpha(25),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF101A8B)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101A8B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(25),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topAbsentStudents(List<QueryDocumentSnapshot> attendanceDocs) {
    final Map<String, int> absentCounts = {};
    final Map<String, String> studentNames = {};

    for (final doc in attendanceDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'absent') {
        final studentId = data['studentId']?.toString() ?? '';
        final studentName = data['studentName']?.toString() ?? 'بدون اسم';

        absentCounts[studentId] = (absentCounts[studentId] ?? 0) + 1;
        studentNames[studentId] = studentName;
      }
    }

    final sortedEntries = absentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('لا توجد حالات غياب مسجلة بعد'),
      );
    }

    final topFive = sortedEntries.take(5).toList();

    return Column(
      children: topFive.map((entry) {
        final name = studentNames[entry.key] ?? 'بدون اسم';
        final count = entry.value;

        return _recordTile(
          title: name,
          subtitle: 'عدد مرات الغياب: $count',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
        );
      }).toList(),
    );
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
        title: const Text('التقارير'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getStudents(),
        builder: (context, studentsSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: getTeachers(),
            builder: (context, teachersSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: getParents(),
                builder: (context, parentsSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: getClasses(),
                    builder: (context, classesSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: getAttendance(),
                        builder: (context, attendanceSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: getBehavior(),
                            builder: (context, behaviorSnapshot) {
                              if (studentsSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                                  teachersSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  parentsSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  classesSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  attendanceSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  behaviorSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final students = studentsSnapshot.data?.docs ?? [];
                              final teachers = teachersSnapshot.data?.docs ?? [];
                              final parents = parentsSnapshot.data?.docs ?? [];
                              final classes = classesSnapshot.data?.docs ?? [];
                              final attendance =
                                  attendanceSnapshot.data?.docs ?? [];
                              final behavior =
                                  behaviorSnapshot.data?.docs ?? [];

                              final presentCount =
                              countAttendanceByStatus(attendance, 'present');
                              final absentCount =
                              countAttendanceByStatus(attendance, 'absent');
                              final lateCount =
                              countAttendanceByStatus(attendance, 'late');

                              final goodBehavior =
                              countBehaviorByType(behavior, 'good');
                              final badBehavior =
                              countBehaviorByType(behavior, 'bad');
                              final noteBehavior =
                              countBehaviorByType(behavior, 'note');

                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF101A8B),
                                          Color(0xFF2337C6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.indigo.withAlpha(40),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'لوحة التقارير',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'تحليل شامل للحضور والسلوك والمستخدمين داخل مؤسستك فقط',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 15,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  _sectionTitle('ملخص عام', Icons.dashboard),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.92,
                                    shrinkWrap: true,
                                    physics:
                                    const NeverScrollableScrollPhysics(),
                                    children: [
                                      _summaryCard(
                                        title: 'عدد الطلاب',
                                        value: '${students.length}',
                                        icon: Icons.school,
                                        color: Colors.indigo,
                                      ),
                                      _summaryCard(
                                        title: 'عدد الأساتذة',
                                        value: '${teachers.length}',
                                        icon: Icons.person,
                                        color: Colors.blue,
                                      ),
                                      _summaryCard(
                                        title: 'عدد الأولياء',
                                        value: '${parents.length}',
                                        icon: Icons.family_restroom,
                                        color: Colors.green,
                                      ),
                                      _summaryCard(
                                        title: 'عدد الأقسام',
                                        value: '${classes.length}',
                                        icon: Icons.class_,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'إحصائيات الحضور',
                                    Icons.fact_check,
                                  ),
                                  GridView.count(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.70,
                                    shrinkWrap: true,
                                    physics:
                                    const NeverScrollableScrollPhysics(),
                                    children: [
                                      _summaryCard(
                                        title: 'حاضر',
                                        value: '$presentCount',
                                        icon: Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      _summaryCard(
                                        title: 'غائب',
                                        value: '$absentCount',
                                        icon: Icons.cancel,
                                        color: Colors.red,
                                      ),
                                      _summaryCard(
                                        title: 'متأخر',
                                        value: '$lateCount',
                                        icon: Icons.access_time,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'إحصائيات السلوك',
                                    Icons.analytics,
                                  ),
                                  GridView.count(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.70,
                                    shrinkWrap: true,
                                    physics:
                                    const NeverScrollableScrollPhysics(),
                                    children: [
                                      _summaryCard(
                                        title: 'جيد',
                                        value: '$goodBehavior',
                                        icon: Icons.thumb_up,
                                        color: Colors.green,
                                      ),
                                      _summaryCard(
                                        title: 'سيئ',
                                        value: '$badBehavior',
                                        icon: Icons.thumb_down,
                                        color: Colors.red,
                                      ),
                                      _summaryCard(
                                        title: 'ملاحظة',
                                        value: '$noteBehavior',
                                        icon: Icons.note_alt,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'أكثر التلاميذ غيابًا',
                                    Icons.warning_amber_rounded,
                                  ),
                                  _topAbsentStudents(attendance),

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'آخر سجلات الحضور',
                                    Icons.history,
                                  ),
                                  if (attendance.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Text(
                                        'لا توجد سجلات حضور بعد',
                                      ),
                                    )
                                  else
                                    ...attendance.take(5).map((doc) {
                                      final data =
                                      doc.data() as Map<String, dynamic>;
                                      return _recordTile(
                                        title:
                                        data['studentName'] ?? 'بدون اسم',
                                        subtitle:
                                        'الحالة: ${data['status'] ?? ''} | التاريخ: ${data['date'] ?? ''}',
                                        icon: Icons.fact_check,
                                        color: Colors.indigo,
                                      );
                                    }),

                                  const SizedBox(height: 28),

                                  _sectionTitle(
                                    'آخر سجلات السلوك',
                                    Icons.assignment,
                                  ),
                                  if (behavior.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Text(
                                        'لا توجد سجلات سلوك بعد',
                                      ),
                                    )
                                  else
                                    ...behavior.take(5).map((doc) {
                                      final data =
                                      doc.data() as Map<String, dynamic>;
                                      return _recordTile(
                                        title:
                                        data['studentName'] ?? 'بدون اسم',
                                        subtitle:
                                        'النوع: ${data['type'] ?? ''} | التاريخ: ${data['date'] ?? ''}',
                                        icon: Icons.assignment,
                                        color: Colors.deepPurple,
                                      );
                                    }),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}