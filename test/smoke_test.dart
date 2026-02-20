import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactbits_text_animations/reactbits_text_animations.dart';

void main() {
  testWidgets('Package widgets build', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SplitText(text: 'Hello'),
        ),
      ),
    );
    expect(find.text('Hello'),
        findsNothing); // animated RichText (widgets build without crash)
  });
}
