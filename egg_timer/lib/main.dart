import 'package:flutter/material.dart';
import 'lab/fragment_lab.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Éclosion — atelier',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff886140)),
      scaffoldBackgroundColor: const Color(0xfff4eee5),
      useMaterial3: true,
    ),
    home: const FragmentLab(),
  );
}
