// lib/pages/ranking_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para toda la pantalla
      appBar: AppBar(
        title: const Text('🏆 Clasificación', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black, // Fondo negro para el AppBar
        iconTheme: IconThemeData(color: Colors.white), // Ícono blanco
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('ranking')
            .orderBy('nivel', descending: true)
            .limit(50)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay datos',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final players = snapshot.data!.docs;

          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final data = players[index].data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Usuario';
              final nivel = data['nivel'] ?? 0;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900], // Fondo oscuro para cada item
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[700]!), // Borde inferior
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.emoji_events, color: Colors.amber),
                  title: Text(
                    nombre,
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    'Nivel $nivel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}