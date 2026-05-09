import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? currentSchoolId;
  String? selectedClassId;
  String teacherName = '';
  bool pageLoading = true;
  bool savingAttendance = false;

  final Map<String, String> attendanceMap = {};

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  String get todayDate {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get nowTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    loadTeacherData();
  }

  Future<void> loadTeacherData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      final data = userDoc.data();

      if (!mounted) return;

      setState(() {
        currentSchoolId = data?['schoolId'];
        teacherName = data?['name'] ?? '';
        pageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => pageLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل بيانات الأستاذ: $e')),
      );
    }
  }

  Future<void> confirmBack(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'تأكيد الرجوع',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF101A8B),
              ),
            ),
            content: const Text(
              'هل أنت متأكد أنك تريد الرجوع إلى الواجهة السابقة؟',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101A8B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('رجوع'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true && context.mounted) {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pop();
    }
  }

  Stream<QuerySnapshot> getMyClasses() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('teacherIds', arrayContains: currentUid)
        .where('schoolId', isEqualTo: currentSchoolId)
        .snapshots();
  }

  Stream<QuerySnapshot> getMyStudents() {
    if (selectedClassId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: currentSchoolId)
        .where('classId', isEqualTo: selectedClassId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTodayAttendance() {
    if (selectedClassId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('attendance')
        .where('schoolId', isEqualTo: currentSchoolId)
        .where('classId', isEqualTo: selectedClassId)
        .where('date', isEqualTo: todayDate)
        .snapshots();
  }

  int countStatus(List<QueryDocumentSnapshot> docs, String status) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == status;
    }).length;
  }

  Future<void> createNotification({
    required String parentId,
    required String studentId,
    required String studentName,
    required String title,
    required String body,
    required String type,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('notifications').doc();

    await docRef.set({
      'notificationId': docRef.id,
      'userId': parentId,
      'studentId': studentId,
      'studentName': studentName,
      'title': title,
      'body': body,
      'type': type,
      'schoolId': currentSchoolId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveAllAttendance(List<QueryDocumentSnapshot> students) async {
    if (selectedClassId == null || currentSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر القسم أولًا')),
      );
      return;
    }

    try {
      setState(() => savingAttendance = true);

      for (final doc in students) {
        final student = doc.data() as Map<String, dynamic>;
        final studentId = doc.id;
        final studentName = student['fullName'] ?? '';
        final parentId = student['parentId'] ?? '';
        final status = attendanceMap[studentId] ?? 'present';
        final attendanceId = '${todayDate}_$studentId';

        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceId)
            .set({
          'attendanceId': attendanceId,
          'studentId': studentId,
          'studentName': studentName,
          'classId': selectedClassId,
          'teacherId': currentUid,
          'schoolId': currentSchoolId,
          'date': todayDate,
          'time': nowTime,
          'status': status,
          'note': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (status == 'absent' && parentId.toString().isNotEmpty) {
          await createNotification(
            parentId: parentId,
            studentId: studentId,
            studentName: studentName,
            title: 'غياب التلميذ',
            body:
            'تم تسجيل غياب $studentName بتاريخ $todayDate على الساعة $nowTime',
            type: 'attendance_absent',
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ حضور القسم بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ الحضور: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => savingAttendance = false);
      }
    }
  }

  Future<void> showAddBehaviorDialog(
      List<QueryDocumentSnapshot> students,
      ) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد تلاميذ في هذا القسم')),
      );
      return;
    }

    String? selectedStudentId;
    String behaviorType = 'note';
    bool saving = false;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveBehavior() async {
              if (selectedStudentId == null ||
                  titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('اختر التلميذ واكتب عنوان السلوك'),
                  ),
                );
                return;
              }

              try {
                setDialogState(() => saving = true);

                final studentDoc =
                students.firstWhere((e) => e.id == selectedStudentId);
                final student = studentDoc.data() as Map<String, dynamic>;
                final studentName = student['fullName'] ?? '';
                final parentId = student['parentId'] ?? '';

                final docRef =
                FirebaseFirestore.instance.collection('behavior').doc();

                await docRef.set({
                  'behaviorId': docRef.id,
                  'studentId': selectedStudentId,
                  'studentName': studentName,
                  'teacherId': currentUid,
                  'classId': selectedClassId,
                  'schoolId': currentSchoolId,
                  'date': todayDate,
                  'time': nowTime,
                  'type': behaviorType,
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (parentId.toString().isNotEmpty) {
                  await createNotification(
                    parentId: parentId,
                    studentId: selectedStudentId!,
                    studentName: studentName,
                    title: 'سلوك جديد للتلميذ',
                    body:
                    'تمت إضافة ملاحظة سلوك لـ $studentName بتاريخ $todayDate على الساعة $nowTime',
                    type: 'behavior_note',
                  );
                }

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ السلوك بنجاح')),
                );
              } catch (e) {
                if (!mounted) return;

                setDialogState(() => saving = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في حفظ السلوك: $e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('إضافة سلوك'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'اختر التلميذ',
                      ),
                      items: students.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(data['fullName'] ?? ''),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                        setDialogState(() {
                          selectedStudentId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: behaviorType,
                      decoration: const InputDecoration(
                        labelText: 'نوع السلوك',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'good', child: Text('جيد')),
                        DropdownMenuItem(value: 'bad', child: Text('سيئ')),
                        DropdownMenuItem(value: 'note', child: Text('ملاحظة')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                        setDialogState(() {
                          behaviorType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'التفاصيل',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveBehavior,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withAlpha(25),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _classSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: getMyClasses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final classes = snapshot.data!.docs;

        if (classes.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('لا توجد أقسام مرتبطة بهذا الأستاذ بعد'),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedClassId,
          decoration: InputDecoration(
            labelText: 'اختر القسم',
            prefixIcon: const Icon(Icons.class_),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          items: classes.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'بدون اسم';
            final grade = data['gradeLevel'] ?? '';
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text('$name - $grade'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedClassId = value;
              attendanceMap.clear();
            });
          },
        );
      },
    );
  }

  Widget attendanceButton({
    required String label,
    required String value,
    required String studentId,
    required Color color,
  }) {
    final selected = (attendanceMap[studentId] ?? 'present') == value;

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            attendanceMap[studentId] = value;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? color.withAlpha(30) : Colors.white,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pageLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final welcomeText = teacherName.isEmpty
        ? 'مرحبًا أيها الأستاذ'
        : 'مرحبًا أيها الأستاذ $teacherName';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Teacher Dashboard',
          style: TextStyle(
            color: Color(0xFF101A8B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => confirmBack(context),
            icon: const Icon(Icons.logout, color: Color(0xFF101A8B)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF101A8B),
                    Color(0xFF2438C8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    welcomeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تاريخ اليوم: $todayDate',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر القسم ثم سجل حضور الطلاب بسرعة.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _classSelector(),
            const SizedBox(height: 20),
            if (selectedClassId == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'اختر قسمًا لعرض الطلاب والإحصائيات',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: getMyStudents(),
                builder: (context, studentsSnapshot) {
                  if (!studentsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final students = studentsSnapshot.data!.docs;

                  return StreamBuilder<QuerySnapshot>(
                    stream: getTodayAttendance(),
                    builder: (context, attendanceSnapshot) {
                      final attendance = attendanceSnapshot.data?.docs ?? [];

                      if (students.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('لا يوجد تلاميذ في هذا القسم بعد'),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.05,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _statCard(
                                title: 'عدد الطلاب',
                                value: '${students.length}',
                                color: Colors.indigo,
                                icon: Icons.groups,
                              ),
                              _statCard(
                                title: 'حاضر اليوم',
                                value: '${countStatus(attendance, 'present')}',
                                color: Colors.green,
                                icon: Icons.check_circle,
                              ),
                              _statCard(
                                title: 'غائب اليوم',
                                value: '${countStatus(attendance, 'absent')}',
                                color: Colors.red,
                                icon: Icons.cancel,
                              ),
                              _statCard(
                                title: 'متأخر اليوم',
                                value: '${countStatus(attendance, 'late')}',
                                color: Colors.orange,
                                icon: Icons.access_time,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'قائمة الطلاب',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101A8B),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  showAddBehaviorDialog(students);
                                },
                                icon: const Icon(Icons.note_add),
                                label: const Text('إضافة سلوك'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ListView.separated(
                            itemCount: students.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = students[index];
                              final student =
                              doc.data() as Map<String, dynamic>;
                              final studentId = doc.id;

                              attendanceMap.putIfAbsent(
                                studentId,
                                    () => 'present',
                              );

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(8),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                          Colors.indigo.withAlpha(25),
                                          child: const Icon(
                                            Icons.school,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            student['fullName'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        attendanceButton(
                                          label: 'حاضر',
                                          value: 'present',
                                          studentId: studentId,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        attendanceButton(
                                          label: 'غائب',
                                          value: 'absent',
                                          studentId: studentId,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        attendanceButton(
                                          label: 'متأخر',
                                          value: 'late',
                                          studentId: studentId,
                                          color: Colors.orange,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: savingAttendance
                                  ? null
                                  : () => saveAllAttendance(students),
                              icon: const Icon(Icons.save),
                              label: savingAttendance
                                  ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                                  : const Text(
                                'حفظ حضور القسم',
                                style: TextStyle(fontSize: 17),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF101A8B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}