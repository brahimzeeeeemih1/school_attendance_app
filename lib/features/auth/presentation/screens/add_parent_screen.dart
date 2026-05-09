import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddParentScreen extends StatefulWidget {
  const AddParentScreen({super.key});

  @override
  State<AddParentScreen> createState() => _AddParentScreenState();
}

class _AddParentScreenState extends State<AddParentScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final searchStudentController = TextEditingController();

  bool loading = false;
  bool pageLoading = true;

  String? currentSchoolId;
  String? selectedStudentId;
  String selectedStudentName = '';

  @override
  void initState() {
    super.initState();
    loadSchoolId();
    searchStudentController.addListener(() {
      setState(() {});
    });
  }

  Future<void> loadSchoolId() async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser!.uid;

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();

      if (!mounted) return;

      setState(() {
        currentSchoolId = adminDoc.data()?['schoolId'];
        pageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => pageLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل schoolId: $e')),
      );
    }
  }

  Stream<QuerySnapshot> getStudentsWithoutParent() {
    return FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: currentSchoolId)
        .where('parentId', isEqualTo: '')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Future<void> addParent() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        selectedStudentId == null ||
        currentSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الاسم + الإيميل + كلمة المرور + اختيار التلميذ مطلوبة'),
        ),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.sendEmailVerification();

      final parentUid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(parentUid).set({
        'uid': parentUid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'parent',
        'schoolId': currentSchoolId,
        'childrenIds': [selectedStudentId],
        'teacherClassIds': [],
        'fcmToken': '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('students')
          .doc(selectedStudentId)
          .update({
        'parentId': parentUid,
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء ولي الأمر وربطه بالتلميذ. يجب تأكيد البريد قبل الدخول.',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'فشل إنشاء الحساب';

      if (e.code == 'email-already-in-use') {
        message = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    searchStudentController.dispose();
    super.dispose();
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget studentSearchSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: getStudentsWithoutParent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final allStudents = snapshot.data!.docs;
        final query = searchStudentController.text.trim().toLowerCase();

        final filteredStudents = allStudents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullName'] ?? '').toString().toLowerCase();
          return query.isEmpty || name.contains(query);
        }).toList();

        if (allStudents.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'لا يوجد تلاميذ بدون ولي. أضف تلميذًا أولًا.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildField(
              controller: searchStudentController,
              label: 'ابحث عن اسم التلميذ',
              icon: Icons.search,
            ),
            const SizedBox(height: 12),

            if (selectedStudentId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'تم اختيار: $selectedStudentName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: filteredStudents.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد نتائج بهذا الاسم'),
                ),
              )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: filteredStudents.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = filteredStudents[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['fullName'] ?? 'بدون اسم';
                  final classId = data['classId'] ?? '';

                  final isSelected = selectedStudentId == doc.id;

                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.school_outlined,
                      color: isSelected
                          ? Colors.green
                          : const Color(0xFF101A8B),
                    ),
                    title: Text(name),
                    subtitle: Text('القسم: $classId'),
                    onTap: () {
                      setState(() {
                        selectedStudentId = doc.id;
                        selectedStudentName = name;
                      });
                    },
                  );
                },
              ),
            ),
          ],
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
        title: const Text('إضافة ولي الأمر'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildField(
              controller: nameController,
              label: 'اسم ولي الأمر',
              icon: Icons.person,
            ),
            const SizedBox(height: 14),
            buildField(
              controller: emailController,
              label: 'البريد الإلكتروني',
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email,
            ),
            const SizedBox(height: 14),
            buildField(
              controller: passwordController,
              label: 'كلمة المرور',
              obscure: true,
              icon: Icons.lock,
            ),
            const SizedBox(height: 14),
            buildField(
              controller: phoneController,
              label: 'رقم الهاتف',
              keyboardType: TextInputType.phone,
              icon: Icons.phone,
            ),
            const SizedBox(height: 14),
            studentSearchSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : addParent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101A8B),
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'إضافة ولي الأمر',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}