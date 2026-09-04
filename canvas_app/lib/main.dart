import 'package:flutter/material.dart';

void main() => runApp(const CanvasRoot());

class CanvasRoot extends StatelessWidget {
  const CanvasRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadcn Canvas',
      home: const Scaffold(body: Center(child: Text('canvas boot'))),
    );
  }
}
