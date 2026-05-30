import 'package:bilitune/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds and renders the shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BiliTuneApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    // The mock "now playing" track title appears in the play bar.
    expect(find.text('夜的第七章'), findsWidgets);
  });
}
