import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // ID único localmente al instalar la app

Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');

  if (userId == null) {
    userId = const Uuid().v4(); // genera ID único
    await prefs.setString('user_id', userId);
  }

  return userId;
}


Future<void> guardarProgresoFirebase() async {

  final prefs = await SharedPreferences.getInstance();
  final playerName = prefs.getString('playerName') ?? 'Usuario';
  final nivel = prefs.getInt('level') ?? 0;

  final userId = await getOrCreateUserId();

  await FirebaseFirestore.instance
      .collection('ranking')
      .doc(userId) // siempre el mismo documento por usuario
      .set({
    'nombre': playerName,
    'nivel': nivel,
  }, SetOptions(merge: true)); // actualiza si ya existe
}
