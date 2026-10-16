import 'package:flutter/material.dart';

void main() => runApp(const YTGetApp());

class YTGetApp extends StatelessWidget {
  const YTGetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTGet',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('YTGet'))),
    );
  }
}
