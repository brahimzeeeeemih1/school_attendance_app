 import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddStudentScreen extends StatefulWidget {
const AddStudentScreen({super.key});

@override
State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
final nameController = TextEditingController();

String? selectedClassId;

bool loading = false;
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

final schoolId = userDoc.data()?['schoolId'];

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

Future<void> addStudent() async {
final studentName = nameController.text.trim();

if (studentName.isEmpty ||
selectedClassId == null ||
currentSchoolId == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('اسم التلميذ والقسم مطلوبان')),
);
return;
}

try {
setState(() => loading = true);

final docRef = FirebaseFirestore.instance.collection('students').doc();

await docRef.set({
'studentId': docRef.id,
'fullName': studentName,
'classId': selectedClassId,
'parentId': '',
'schoolId': currentSchoolId,
'isActive': true,
'createdAt': FieldValue.serverTimestamp(),
});

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('تمت إضافة التلميذ بنجاح')),
);

nameController.clear();

setState(() {
selectedClassId = null;
});
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('خطأ: $e')),
);
} finally {
if (mounted) setState(() => loading = false);
}
}

Stream<QuerySnapshot> getClasses() {
return FirebaseFirestore.instance
    .collection('classes')
    .where('schoolId', isEqualTo: currentSchoolId)
    .snapshots();
}

@override
void dispose() {
nameController.dispose();
super.dispose();
}

Widget buildField({
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
borderRadius: BorderRadius.circular(16),
borderSide: BorderSide.none,
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

return Scaffold(
backgroundColor: const Color(0xFFF5F6FA),
appBar: AppBar(
title: const Text('إضافة تلميذ'),
backgroundColor: Colors.white,
),
body: Padding(
padding: const EdgeInsets.all(16),
child: ListView(
children: [
buildField(
controller: nameController,
 label: 'اسم التلميذ',
icon: Icons.school,
),
const SizedBox(height: 20),
StreamBuilder<QuerySnapshot>(
stream: getClasses(),
builder: (context, snapshot) {
if (!snapshot.hasData) {
return const LinearProgressIndicator();
}

final docs = snapshot.data!.docs;

if (docs.isEmpty) {
return Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.orange.shade50,
borderRadius: BorderRadius.circular(14),
),
child: const Text('لا توجد أقسام بعد. أضف قسمًا أولًا.'),
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
items: docs.map((doc) {
final data = doc.data() as Map<String, dynamic>;
final name = data['name'] ?? 'بدون اسم';
final grade = data['gradeLevel'] ?? '';

return DropdownMenuItem<String>(
value: doc.id,
child: Text('$name - $grade'),
);
}).toList(),
onChanged: (value) {
setState(() => selectedClassId = value);
},
);
},
),
const SizedBox(height: 30),
SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton(
onPressed: loading ? null : addStudent,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF101A8B),
foregroundColor: Colors.white,
),
child: loading
? const CircularProgressIndicator(color: Colors.white)
    : const Text(
'إضافة التلميذ',
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