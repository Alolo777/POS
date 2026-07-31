import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_flutter_firebase/features/auth/data/auth_service.dart';
import 'package:pos_flutter_firebase/features/auth/ui/login_screen.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: LoginScreen(authService: mockAuthService),
    );
  }

  group('LoginScreen', () {
    testWidgets('shows login form by default', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Iniciar sesion'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('No tienes cuenta? Registrate'), findsOneWidget);
    });

    testWidgets('toggles to register mode', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('No tienes cuenta? Registrate'));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Registrarme'), findsOneWidget);
      expect(find.text('Ya tienes cuenta? Inicia sesion'), findsOneWidget);
    });

    testWidgets('shows error when email and password are empty', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Ingresa correo y contrasena'), findsOneWidget);
    });

    testWidgets('shows error when business name is empty in register mode', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('No tienes cuenta? Registrate'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), ''); // business name empty
      await tester.enterText(find.byType(TextField).at(2), 'password123');

      await tester.tap(find.text('Registrarme'));
      await tester.pump();

      expect(find.text('Ingresa el nombre de tu empresa'), findsOneWidget);
    });

    testWidgets('calls signIn on form submission', (tester) async {
      when(() => mockAuthService.signIn(any(), any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.signIn('test@test.com', 'password123')).called(1);
    });

    testWidgets('calls signUp on register form submission', (tester) async {
      when(() => mockAuthService.signUp(any(), any(), any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('No tienes cuenta? Registrate'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'new@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'Mi Negocio');
      await tester.enterText(find.byType(TextField).at(2), 'password123');

      await tester.tap(find.text('Registrarme'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.signUp('new@test.com', 'password123', 'Mi Negocio')).called(1);
    });

    testWidgets('displays error message from signIn', (tester) async {
      when(() => mockAuthService.signIn(any(), any()))
          .thenAnswer((_) async => 'Error de prueba');

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Error de prueba'), findsOneWidget);
    });

    testWidgets('shows loading indicator while submitting', (tester) async {
      final completer = Completer<String?>();
      when(() => mockAuthService.signIn(any(), any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows forgot password dialog and sends reset email', (tester) async {
      when(() => mockAuthService.sendPasswordReset(any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar contrasena'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('forgotEmailField')), 'user@test.com');
      await tester.tap(find.byKey(const Key('forgotSubmitButton')));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.sendPasswordReset('user@test.com')).called(1);
      expect(find.text('Recuperar contrasena'), findsNothing);
      expect(find.text('Te enviamos un correo para restablecer tu contrasena'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('forgot password shows error when email is empty', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forgotSubmitButton')));
      await tester.pump();

      expect(find.text('Ingresa tu correo'), findsOneWidget);
      verifyNever(() => mockAuthService.sendPasswordReset(any()));
    });

    testWidgets('forgot password shows service error inside dialog', (tester) async {
      when(() => mockAuthService.sendPasswordReset(any()))
          .thenAnswer((_) async => 'No existe una cuenta con ese correo');

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('forgotEmailField')), 'nobody@test.com');
      await tester.tap(find.byKey(const Key('forgotSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar contrasena'), findsOneWidget);
      expect(find.text('No existe una cuenta con ese correo'), findsOneWidget);
    });
  });
}
