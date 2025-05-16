import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

ThemeData _currentTheme = ThemeData.light(); // Ajusta según tus necesidades

Widget _buildGlassButton({
  required String text,
  required VoidCallback onPressed,
}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withOpacity(0.2),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    onPressed: onPressed,
    child: Center(
      // Esto centra todo el contenido
      child: Text(
        text,
        textAlign: TextAlign.center, // Esto centra el texto dentro del botón
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

void showGameRules(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _currentTheme.colorScheme.primary.withOpacity(0.9),
                _currentTheme.colorScheme.secondary.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _currentTheme.textTheme.bodyLarge!.color!.withOpacity(
                0.2,
              ), // Usando bodyLarge
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título con un gradiente dinámico de colores
              Text(
                tr('game_rules_title'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  foreground:
                      Paint()
                        ..shader = LinearGradient(
                          colors: [
                            Colors.purple.shade400,
                            Colors.blue.shade500,
                            Colors.cyan.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(
                          Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                        ), // Usando un gradiente
                ),
              ),
              SizedBox(height: 20),

              // Descripción con un color más vibrante y opacidad ajustada
              Text(
                tr('game_rules_description'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blueAccent.withOpacity(
                    0.8,
                  ), // Color azul brillante
                  fontStyle: FontStyle.italic, // Estilo en cursiva
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              // Botón con un color vibrante para resaltar
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        Colors.blueAccent, // Cambia el color de fondo
                  ),
                  child: Text(
                    tr('understood'),
                    style: TextStyle(
                      color: Colors.white,
                    ), // Cambia el color del texto
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
