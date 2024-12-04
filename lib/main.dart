import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'pages.dart';

void main() {
  runApp(const PVApp());
}

class PVApp extends StatelessWidget {
  const PVApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PictureVert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const LoaderOverlay(
          child: PVPage(title: 'Artful Picture Conversions')),
    );
  }
}
