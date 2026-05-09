import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentActionScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;
  final String teacherId;

  const StudentActionScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.teacherId,
  });

  @override
  State<StudentActionScreen> createState() => _StudentActionScreenState();
}

class _StudentActionScreenState extends State<StudentActionScreen> {
  String attendanceStatus = 'present';
  String behaviorType = 'good';

  final attendanceNoteController = TextEditingController();
  final behaviorTitleController = TextEditingController();
  final behaviorDescriptionController = TextEditingController();

  bool savingAttendance = false;
  bool savingBehavior = false;
  bool pageLoading = true;

  String? currentSchoolId;

  @override
  void initState() {
    super.initState();
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

  String get todayDate {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get nowTime {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<String?> getParentId() async {
    final studentDoc = await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.studentId)
        .get();

    if (!studentDoc.exists) return null;

    final data = studentDoc.data();
    return data?['parentId'];
  }

  Future<void> createNotification({
    required String parentId,
    required String title,
    required String body,
    required String type,
  }) async {
    if (currentSchoolId == null) return;

    final docRef = FirebaseFirestore.instance.collection('notifications').doc();

    await docRef.set({
      'notificationId': docRef.id,
      'userId': parentId,
      'studentId': widget.studentId,
      'studentName': widget.studentName,
      'title': title,
      'body': body,
      'type': type,
      'schoolId': currentSchoolId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveAttendance() async {
    if (currentSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('schoolId غير موجود')),
      );
      return;
    }

    try {
      setState(() => savingAttendance = true);

      final attendanceId = '${todayDate}_${widget.studentId}';

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendanceId)
          .set({
        'attendanceId': attendanceId,
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'classId': widget.classId,
        'teacherId': widget.teacherId,
        'schoolId': currentSchoolId,
        'date': todayDate,
        'time': nowTime,
        'status': attendanceStatus,
        'note': attendanceNoteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (attendanceStatus == 'absent') {
        final parentId = await getParentId();

        if (parentId != null && parentId.isNotEmpty) {
          await createNotification(
            parentId: parentId,
            title: 'غياب التلميذ',
            body:
            'تم تسجيل غياب ${widget.studentName} بتاريخ $todayDate على الساعة $nowTime',
            type: 'attendance_absent',
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attendanceStatus == 'absent'
                ? 'تم تسجيل غياب ${widget.studentName} بتاريخ $todayDate'
                : 'تم حفظ الحضور بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ الحضور: $e')),
      );
    } finally {
      if (mounted) setState(() => savingAttendance = false);
    }
  }

  Future<void> saveBehavior() async {
    if (currentSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('schoolId غير موجود')),
      );
      return;
    }

    try {
      setState(() => savingBehavior = true);

      final docRef = FirebaseFirestore.instance.collection('behavior').doc();

      await docRef.set({
        'behaviorId': docRef.id,
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'teacherId': widget.teacherId,
        'classId': widget.classId,
        'schoolId': currentSchoolId,
        'date': todayDate,
        'time': nowTime,
        'type': behaviorType,
        'title': behaviorTitleController.text.trim(),
        'description': behaviorDescriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final parentId = await getParentId();

      if (parentId != null && parentId.isNotEmpty) {
        await createNotification(
          parentId: parentId,
          title: 'سلوك جديد للتلميذ',
          body:
          'تمت إضافة ملاحظة سلوك لـ ${widget.studentName} بتاريخ $todayDate على الساعة $nowTime',
          type: 'behavior_note',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ السلوك بنجاح')),
      );

      behaviorTitleController.clear();
      behaviorDescriptionController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ السلوك: $e')),
      );
    } finally {
      if (mounted) setState(() => savingBehavior = false);
    }
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF101A8B),
          ),
        ),
      ),
    );
  }

  Widget buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String label,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildAttendanceHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: widget.studentId)
          .where('schoolId', isEqualTo: currentSchoolId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aDate = '${aData['date'] ?? ''} ${aData['time'] ?? ''}';
          final bDate = '${bData['date'] ?? ''} ${bData['time'] ?? ''}';

          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return const Text('لا يوجد سجل حضور لهذا التلميذ بعد');
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final status = data['status'] ?? '';
            final date = data['date'] ?? '';
            final time = data['time'] ?? '';
            final note = data['note'] ?? '';

            Color color;
            String label;

            switch (status) {
              case 'present':
                color = Colors.green;
                label = 'حاضر';
                break;
              case 'absent':
                color = Colors.red;
                label = 'غائب';
                break;
              case 'late':
                color = Colors.orange;
                label = 'متأخر';
                break;
              default:
                color = Colors.grey;
                label = status.toString();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withAlpha(30),
                    child: Icon(Icons.calendar_month, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('التاريخ: $date',
                            style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                        if (time.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('الوقت: $time'),
                        ],
                        const SizedBox(height: 4),
                        Text('الحالة: $label'),
                        if (note.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('ملاحظة: $note'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    attendanceNoteController.dispose();
    behaviorTitleController.dispose();
    behaviorDescriptionController.dispose();
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF101A8B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تاريخ اليوم: $todayDate',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الوقت الحالي: $nowTime',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle('تسجيل الحضور'),
            buildDropdown(
              value: attendanceStatus,
              label: 'حالة الحضور',
              items: const [
                DropdownMenuItem(value: 'present', child: Text('حاضر')),
                DropdownMenuItem(value: 'absent', child: Text('غائب')),
                DropdownMenuItem(value: 'late', child: Text('متأخر')),
              ],
              onChanged: (value) {
                setState(() {
                  attendanceStatus = value!;
                });
              },
            ),
            const SizedBox(height: 14),
            buildField(
              controller: attendanceNoteController,
              label: 'ملاحظة الحضور (اختياري)',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: savingAttendance ? null : saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: savingAttendance
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'حفظ الحضور',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 30),
            buildSectionTitle('إضافة سلوك'),
            buildDropdown(
              value: behaviorType,
              label: 'نوع السلوك',
              items: const [
                DropdownMenuItem(value: 'good', child: Text('جيد')),
                DropdownMenuItem(value: 'bad', child: Text('سيئ')),
                DropdownMenuItem(value: 'note', child: Text('ملاحظة')),
              ],
              onChanged: (value) {
                setState(() {
                  behaviorType = value!;
                });
              },
            ),
            const SizedBox(height: 14),
            buildField(
              controller: behaviorTitleController,
              label: 'عنوان السلوك',
            ),
            const SizedBox(height: 14),
            buildField(
              controller: behaviorDescriptionController,
              label: 'تفاصيل السلوك',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: savingBehavior ? null : saveBehavior,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101A8B),
                  foregroundColor: Colors.white,
                ),
                child: savingBehavior
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'حفظ السلوك',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 30),
            buildSectionTitle('سجل الحضور'),
            buildAttendanceHistory(),
          ],
        ),
      ),
    );
  }
}