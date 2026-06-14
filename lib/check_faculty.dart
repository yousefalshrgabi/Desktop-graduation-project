import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  final snap = await db.collection('faculty_members').get();
  print('Total faculty members: ${snap.docs.length}');

  for (var doc in snap.docs) {
    final data = doc.data();
    final name = data['name'] ?? data['personal_info']?['name'];
    final dept =
        data['department'] ?? data['academic_department']?['department'];
    final college = data['college'] ?? data['academic_department']?['college'];
    print('ID: ${doc.id}, Name: $name, Dept: $dept, College: $college');
  }
}
