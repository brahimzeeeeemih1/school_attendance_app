import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'teacher_dashboard.dart';
import 'parent_dashboard.dart';

enum UserRole { admin, teacher, parent }

class LoginScreen extends StatefulWidget {
 const LoginScreen({super.key});

 @override
 State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
 final emailController = TextEditingController();
 final passwordController = TextEditingController();

 bool loading = false;
 bool _obscurePassword = true; // متغير التحكم في رؤية كلمة المرور
 UserRole selectedRole = UserRole.admin;

 Future<void> login() async {
  try {
   setState(() => loading = true);

   final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: emailController.text.trim(),
    password: passwordController.text.trim(),
   );

   final user = credential.user!;
   final uid = user.uid;

   await user.reload();

   final refreshedUser = FirebaseAuth.instance.currentUser!;

   if (!refreshedUser.emailVerified) {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(
      content: Text('يجب تأكيد البريد الإلكتروني أولًا. تحقق من بريدك.'),
     ),
    );

    return;
   }

   final userDoc = await FirebaseFirestore.instance
       .collection('users')
       .doc(uid)
       .get();

   if (!userDoc.exists) {
    throw Exception('User document not found');
   }

   final role = (userDoc.data()?['role'] ?? '').toString().toLowerCase();
   final isActive = userDoc.data()?['isActive'] ?? true;

   if (isActive == false) {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content: Text('تم تعطيل هذا الحساب')),
    );

    return;
   }

   if (!mounted) return;

   Widget page;

   switch (role) {
    case 'admin':
     page = const AdminDashboard();
     break;
    case 'teacher':
     page = const TeacherDashboard();
     break;
    case 'parent':
     page = const ParentDashboard();
     break;
    default:
     throw Exception('Unknown role');
   }

   Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
   );
  } on FirebaseAuthException catch (e) {
   String message = 'فشل تسجيل الدخول';

   if (e.code == 'user-not-found') {
    message = 'المستخدم غير موجود';
   } else if (e.code == 'wrong-password') {
    message = 'كلمة المرور غير صحيحة';
   } else if (e.code == 'invalid-email') {
    message = 'البريد الإلكتروني غير صالح';
   } else if (e.code == 'invalid-credential') {
    message = 'بيانات الدخول غير صحيحة';
   }

   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
   );
  } catch (e) {
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('فشل تسجيل الدخول: $e')),
   );
  } finally {
   if (mounted) setState(() => loading = false);
  }
 }

 Future<void> showCreateAdminDialog() async {
  final nameController = TextEditingController();
  final adminEmailController = TextEditingController();
  final adminPasswordController = TextEditingController();

  await showDialog(
   context: context,
   barrierDismissible: false,
   builder: (dialogContext) {
    bool creating = false;
    bool _dialogObscure = true; // متغير منفصل للنافذة المنبثقة

    return StatefulBuilder(
     builder: (context, setDialogState) {
      Future<void> createAdmin() async {
       final name = nameController.text.trim();
       final email = adminEmailController.text.trim();
       final password = adminPasswordController.text.trim();

       if (name.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(this.context).showSnackBar(
         const SnackBar(content: Text('جميع الحقول مطلوبة')),
        );
        return;
       }

       setDialogState(() => creating = true);


       try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
         email: email,
         password: password,
        );

        await credential.user!.sendEmailVerification();

        final uid = credential.user!.uid;

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
         'uid': uid,
         'name': name,
         'email': email,
         'phone': '',
         'role': 'admin',
         'schoolId': uid,
         'childrenIds': [],
         'teacherClassIds': [],
         'fcmToken': '',
         'isActive': true,
         'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.of(dialogContext).pop();

        ScaffoldMessenger.of(this.context).showSnackBar(
         const SnackBar(
          content: Text(
           'تم إنشاء حساب مسؤول. تحقق من بريدك الإلكتروني ثم سجل الدخول.',
          ),
         ),
        );
       } on FirebaseAuthException catch (e) {
        String message = 'فشل إنشاء الحساب';

        if (e.code == 'email-already-in-use') {
         message = 'البريد الإلكتروني مستخدم بالفعل';
        } else if (e.code == 'weak-password') {
         message = 'كلمة المرور ضعيفة جدًا';
        } else if (e.code == 'invalid-email') {
         message = 'البريد الإلكتروني غير صالح';
        }

        if (!mounted) return;

        setDialogState(() => creating = false);

        ScaffoldMessenger.of(this.context).showSnackBar(
         SnackBar(content: Text(message)),
        );
       } catch (e) {
        if (!mounted) return;

        setDialogState(() => creating = false);

        ScaffoldMessenger.of(this.context).showSnackBar(
         SnackBar(content: Text('خطأ: $e')),
        );
       }
      }

      return AlertDialog(
       title: const Text('إنشاء حساب مسؤول'),
       content: SingleChildScrollView(
        child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
          TextField(
           controller: nameController,
           decoration: const InputDecoration(
            labelText: 'اسم المسؤول',
           ),
          ),
          const SizedBox(height: 12),
          TextField(
           controller: adminEmailController,
           keyboardType: TextInputType.emailAddress,
           decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
           ),
          ),
          const SizedBox(height: 12),
          TextField(
           controller: adminPasswordController,
           obscureText: _dialogObscure,
           decoration: InputDecoration(
            labelText: 'كلمة المرور',
            suffixIcon: IconButton(
             icon: Icon(_dialogObscure ? Icons.visibility_off : Icons.visibility),
             onPressed: () => setDialogState(() => _dialogObscure = !_dialogObscure),
            ),
           ),
          ),
         ],
        ),
       ),
       actions: [
        TextButton(
         onPressed: creating
             ? null
             : () => Navigator.of(dialogContext).pop(),
         child: const Text('إلغاء'),
        ),
        ElevatedButton(
         onPressed: creating ? null : createAdmin,
         child: creating
             ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
         )
             : const Text('إنشاء'),
        ),
       ],
      );
     },
    );
   },
  );
 }

 @override
 void dispose() {
  emailController.dispose();
  passwordController.dispose();
  super.dispose();
 }

 Widget _roleCard(String label, IconData icon, UserRole role) {
  final selected = selectedRole == role;


  return Expanded(
   child: GestureDetector(
    onTap: () => setState(() => selectedRole = role),
    child: Container(
     margin: const EdgeInsets.symmetric(horizontal: 4),
     padding: const EdgeInsets.all(12),
     decoration: BoxDecoration(
      color: selected ? Colors.white : Colors.grey.shade300,
      border: Border.all(
       color: selected ? Colors.indigo : Colors.transparent,
       width: 2,
      ),
      borderRadius: BorderRadius.circular(12),
     ),
     child: Column(
      children: [
       Icon(icon, color: Colors.indigo),
       const SizedBox(height: 5),
       Text(label),
      ],
     ),
    ),
   ),
  );
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   backgroundColor: const Color(0xFFF3F4F6),
   body: SafeArea(
    child: Padding(
     padding: const EdgeInsets.all(20),
     child: ListView(
      children: [
       const SizedBox(height: 40),
       Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
         color: Colors.indigo,
         borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.school, color: Colors.white, size: 40),
       ),
       const SizedBox(height: 20),
       const Text(
        'EduAttend',
        textAlign: TextAlign.center,
        style: TextStyle(
         fontSize: 22,
         fontWeight: FontWeight.bold,
         color: Colors.indigo,
        ),
       ),
       const SizedBox(height: 30),
       const Text(
        'مرحباً بك مجدداً',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
       ),
       const SizedBox(height: 10),
       const Text(
        'يرجى اختيار دورك وإدخال بيانات الاعتماد الخاصة بك.',
        textAlign: TextAlign.center,
       ),
       const SizedBox(height: 30),
       Row(
        children: [
         _roleCard('مسؤول', Icons.shield, UserRole.admin),
         _roleCard(' استاذ', Icons.person, UserRole.teacher),
         _roleCard('ولي أمر', Icons.family_restroom, UserRole.parent),
        ],
       ),
       const SizedBox(height: 30),
       TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
         hintText: 'البريد الإلكتروني',
         filled: true,
        ),
       ),
       const SizedBox(height: 15),
       TextField(
        controller: passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
         hintText: 'كلمة المرور',
         filled: true,
         suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
         ),
        ),
       ),
       const SizedBox(height: 30),
       SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
         onPressed: loading ? null : login,
         child: loading
             ? const CircularProgressIndicator()
             : const Text('تسجيل الدخول'),
        ),
       ),
       const SizedBox(height: 16),
       if (selectedRole == UserRole.admin)
        SizedBox(
         width: double.infinity,
         height: 50,
         child: OutlinedButton(
          onPressed: showCreateAdminDialog,
          child: const Text('إنشاء حساب مسؤول'),
         ),
        ),
      ],
     ),
    ),
   ),
  );
 }
}
