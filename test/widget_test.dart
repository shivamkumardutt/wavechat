
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavechat/auth/auth_screen.dart';

void main() {
  testWidgets('WaveChat login screen renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () {}),
      ),
    );

    expect(find.text('WaveChat'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('Registration form can be opened', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthenticated: () {}),
      ),
    );

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}
