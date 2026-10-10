import 'package:flutter/material.dart';
import 'lab/egg_geometry_preview.dart';

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
    home: const EggGeometryPreview(),
  );
}
