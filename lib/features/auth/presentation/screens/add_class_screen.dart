import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddClassScreen extends StatefulWidget {
  const AddClassScreen({super.key});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  final classNameController = TextEditingController();
  final gradeLevelController = TextEditingController();

  final List<String> selectedTeacherIds = [];

  String? currentSchoolId;

  bool loading = false;
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

      final data = userDoc.data();

      String? schoolId = data?['schoolId'];

      if (schoolId == null || schoolId.isEmpty) {
        schoolId = currentUid;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .set({
          'schoolId': schoolId,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      setState(() {
        currentSchoolId = schoolId;
        pageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        pageLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل schoolId: $e')),
      );
    }
  }

  Stream<QuerySnapshot> getTeachers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('schoolId', isEqualTo: currentSchoolId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Future<void> addClass() async {
    final className = classNameController.text.trim();
    final gradeLevel = gradeLevelController.text.trim();

    if (className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم القسم مطلوب')),
      );
      return;
    }

    if (gradeLevel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المستوى الدراسي مطلوب')),
      );
      return;
    }

    if (selectedTeacherIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أستاذًا واحدًا على الأقل')),
      );
      return;
    }

    if (currentSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('schoolId غير موجود')),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final docRef = FirebaseFirestore.instance.collection('classes').doc();

      await docRef.set({
        'classId': docRef.id,
        'name': className,
        'gradeLevel': gradeLevel,
        'teacherIds': selectedTeacherIds,
        'schoolId': currentSchoolId,
        'studentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة القسم بنجاح')),
      );

      classNameController.clear();
      gradeLevelController.clear();

      setState(() {
        selectedTeacherIds.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    classNameController.dispose();
    gradeLevelController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _teacherSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: getTeachers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final teachers = snapshot.data!.docs;

        if (teachers.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'لا يوجد أساتذة تابعون لهذا الحساب حتى الآن.',
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.badge),
                  SizedBox(width: 8),
                  Text(
                    'اختر الأساتذة الذين يدرسون هذا القسم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...teachers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final teacherName = data['name'] ?? 'بدون اسم';
                final selected = selectedTeacherIds.contains(doc.id);

                return CheckboxListTile(
                  value: selected,
                  title: Text(teacherName),
                  subtitle: Text(data['email'] ?? ''),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedTeacherIds.add(doc.id);
                      } else {
                        selectedTeacherIds.remove(doc.id);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
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
        title: const Text('إضافة قسم'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildField(
              controller: classNameController,
              label: 'اسم القسم',
              icon: Icons.class_,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: gradeLevelController,
              label: 'المستوى الدراسي',
              icon: Icons.school,
            ),
            const SizedBox(height: 14),
            _teacherSelector(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: loading ? null : addClass,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101A8B),
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'حفظ القسم',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
