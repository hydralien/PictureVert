import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PictureVert',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,
      ),
      home: const MyHomePage(title: 'Picture Negative Conversion'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _currentSliderValue = 0;
  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  Uint8List? invertedImage;
  img.Image? previewData;
  Uint8List? imagePreview;
  Uint8List? invertedImagePreview;

  img.Image invertImage(img.Image src, num shiftCoefficient) {
    log("Preview invert " + shiftCoefficient.toString());
    final pixels = src.getBytes();

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      var pixel = pixels[pixelId];
      if ((pixelId + 1) % 4 == 0) continue; // alpha channel
      num newPixel = 255 - pixels[pixelId];
      num difference = pixel - newPixel;
      pixels[pixelId] = (newPixel + difference * shiftCoefficient).clamp(0, 255).toInt();
    }

    return src;
  }

  Future buildPreview({double width = 0}) async {
    var imageData = img.decodeImage(await imageFile!.readAsBytes());

    if (width == 0) width = MediaQuery.of(context).size.width;
    var coefficient = width / imageData!.width;

    previewData = img.copyResize(imageData, width: width.toInt(), height: (imageData.height * coefficient).toInt());

    imagePreview = Uint8List.fromList(
        img.encodeJpg( previewData! )
    );
  }

  invertPreview() {
    var coefficient = _currentSliderValue / 100;
    var invertedPreview = invertImage(previewData!.clone(), coefficient);
    invertedImagePreview = Uint8List.fromList(
        img.encodeJpg( invertedPreview )
    );
  }

  void _loadedImage() async {
    log("Image loaded!");

    await buildPreview();
    invertPreview();
    // var imageData = img.decodeImage(await imageFile!.readAsBytes());
    // imageData = invertImage(imageData!, _currentSliderValue);

    setState(() {
      // invertedImage = Uint8List.fromList(img.encodeJpg(imageData!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            imagePreview != null ? Image.memory(
              imagePreview!,
              fit: BoxFit.cover
            ) : const SizedBox(width: 0, height: 0),
            ElevatedButton(
              onPressed: () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() {
                    imageFile = File(image.path);
                    _loadedImage();
                  });
                }
                // Respond to button press
              },
              child: Text('Open image'),
            ),
            Slider(
              value: _currentSliderValue,
              max: 100,
              min: -100,
              // divisions: 50,
              label: _currentSliderValue.round().toString(),
              onChanged: invertedImagePreview != null ? (double value) {
                setState(() {
                  _currentSliderValue = value;
                });
              } : null,
              onChangeEnd: (double value) {
                setState(() {
                  invertPreview();
                });
              }
            ),
            invertedImagePreview != null ?
            Image.memory(
                invertedImagePreview!,
                fit: BoxFit.cover
            ) : const SizedBox(width: 0, height: 0),
          ],
        ),
      )
    );
  }
}
