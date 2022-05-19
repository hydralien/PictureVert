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
  double _inversionRangeSliderValue = 0;

  bool _loadingImage = false;
  bool _loadingInverted = false;
  bool _conversionPending = false;

  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  img.Image? previewData;
  Uint8List? imagePreview;
  Uint8List? invertedImagePreview;

  void _resetImages() {
    setState(() {
      imageFile = null;
      previewData = null;
      imagePreview = null;
      invertedImagePreview = null;
      _inversionRangeSliderValue = 0;
    });
  }

  img.Image invertImage(img.Image src, num shiftCoefficient) {
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
    setState(() { _loadingImage = true; });
    var imageData = img.decodeImage(await imageFile!.readAsBytes());

    if (width == 0) width = MediaQuery.of(context).size.width;
    var coefficient = width / imageData!.width;

    previewData = img.copyResize(imageData, width: width.toInt(), height: (imageData.height * coefficient).toInt());

    imagePreview = Uint8List.fromList(
        img.encodeJpg( previewData! )
    );

    setState(() { _loadingImage = false; });
  }

  invertPreview() async {
    setState(() { _loadingInverted = true; });

    var coefficient = _inversionRangeSliderValue / 100;
    var invertedPreview = invertImage(previewData!.clone(), coefficient);
    invertedImagePreview = Uint8List.fromList(
        img.encodeJpg( invertedPreview )
    );

    setState(() { _loadingInverted = false; });
  }

  void _loadedImage() async {
    log("Image loaded!");

    await buildPreview();
    await invertPreview();
  }

  Widget _placeholder(Uint8List? imageDataHolder, bool isLoading) {
    if (imageDataHolder != null) {
      return Image.memory(
          imageDataHolder,
          fit: BoxFit.cover
      );
    }

    if (isLoading) {
      return const CircularProgressIndicator();
    }

    return  const SizedBox(width: 0, height: 0);
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
        child: ListView(
          children: <Widget>[
            _placeholder(imagePreview, _loadingImage),
            ElevatedButton(
              onPressed: () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  _resetImages();
                  setState(() {
                    imageFile = File(image.path);
                    _loadedImage();
                  });
                }
                // Respond to button press
              },
              child: const Text('Open image'),
            ),
            Slider(
              value: _inversionRangeSliderValue,
              max: 100,
              min: -100,
              // divisions: 50,
              label: _inversionRangeSliderValue.round().toString(),
              onChanged: invertedImagePreview != null ? (double value) {
                setState(() {
                  _inversionRangeSliderValue = value;
                });
              } : null,
              onChangeEnd: (double value) {
                setState(() {
                  invertPreview();
                });
              }
            ),
            _placeholder(invertedImagePreview, _loadingInverted),
          ],
        ),
      )
    );
  }
}
