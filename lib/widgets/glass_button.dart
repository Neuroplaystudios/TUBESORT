import 'package:flutter/material.dart';
import '../managers/sound_manager.dart'; // Asegúrate que la ruta sea correcta

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? iconColor; // Color específico para el ícono
  final Color textColor;
  final List<Color> gradientColors;
  final Color borderColor;

  const GlassButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.iconColor,
    required this.textColor,
    required this.gradientColors,
    required this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // El Material no debe tener color de fondo
      borderRadius: BorderRadius.circular(30),
      elevation: 8,
      child: InkWell(
        onTap: () {
          SoundManager.playSound('select');
          onPressed();
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.7)).toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: borderColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? textColor), // Usa iconColor si se provee
                SizedBox(width: 8), // Incrementado para más espacio
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}