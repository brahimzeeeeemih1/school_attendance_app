import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddTeacherScreen extends StatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = false;

  Future<void> addTeacher() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    // ✅ تحقق من الحقول
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم + الإيميل + كلمة المرور مطلوبة')),
      );
      return;
    }

    try {
      setState(() => loading = true);

      // 🧠 نحفظ admin الحالي قبل إنشاء Teacher
      final currentAdmin = FirebaseAuth.instance.currentUser;
      final adminEmail = currentAdmin!.email;

      // 1️⃣ إنشاء Teacher في Authentication
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.sendEmailVerification();

      final teacherUid = credential.user!.uid;

      // 2️⃣ جلب schoolId من admin
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentAdmin.uid)
          .get();

      final schoolId = adminDoc.data()?['schoolId'];

      // 3️⃣ حفظ في Firestore بنفس uid
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .set({
        'uid': teacherUid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'teacher',
        'schoolId': schoolId,
        'teacherClassIds': [],
        'childrenIds': [],
        'fcmToken': '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الأستاذ بنجاح')),
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
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black87),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      // ✅ يضمن إعادة حساب المساحة عند ظهور الكيبورد
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('إضافة أستاذ'),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      // ✅ SingleChildScrollView يحل مشكلة Overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildField(
              controller: nameController,
              hint: 'اسم الأستاذ',
              icon: Icons.person,
            ),
            _buildField(
              controller: emailController,
              hint: 'البريد الإلكتروني',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock,
              obscure: true,
            ),
            _buildField(
              controller: phoneController,
              hint: 'رقم الهاتف',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : addTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1B73),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'إضافة أستاذ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}