

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_casillas_colores2/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ColorSortGame());

    // Este test no aplica directamente porque no tienes un contador.
    // Lo puedes eliminar o adaptar a otra lógica más relevante.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
