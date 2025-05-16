import 'package:flutter/material.dart';

class JumpingTitle extends StatefulWidget {
  final VoidCallback? onCompleted;
  const JumpingTitle({this.onCompleted});

  @override
  _JumpingTitleState createState() => _JumpingTitleState();
}

class _JumpingTitleState extends State<JumpingTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Define una secuencia de rebotes con desplazamiento lateral e inferior
    _animation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(-1, 0),
          end: Offset(1, 0.2),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(1, 0.2),
          end: Offset(-0.8, 0.4),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(-0.8, 0.4),
          end: Offset(0.8, 0.6),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(0.8, 0.6),
          end: Offset(0, 0.8),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_controller);

    _controller.forward().whenComplete(() {
      if (widget.onCompleted != null) {
        widget.onCompleted!(); // Este es el callback cuando termina
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: Image.asset(
        'assets/title/titletubesort.png', // Asegúrate de que esta imagen tenga fondo transparente
        width: 280,
        height: 100,
        fit: BoxFit.contain,
      ),
    );
  }
}
