import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      home: const LoaderOverlay(
          child: MyHomePage(title: 'Picture Negative Conversion')
      ),
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

  final ScrollController _scrollController = ScrollController();

  bool _loadingImage = false;
  bool _loadingInverted = false;
  bool _exportingInverted = false;

  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  img.Image? previewData;
  Uint8List? imagePreview;
  Uint8List? invertedImagePreview;

  double inversionCoefficient() {
    return _inversionRangeSliderValue / 100;
  }

  void _resetImages() {
    imageFile = null;
    previewData = null;
    imagePreview = null;
    invertedImagePreview = null;
    _inversionRangeSliderValue = 0;
  }

  ButtonStyle _buttonStyle() {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      textStyle: const TextStyle(fontSize: 20),
    );
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
      pixels[pixelId] =
          (newPixel + difference * shiftCoefficient).clamp(0, 255).toInt();
    }

    return src;
  }

  Future buildPreview({double width = 0}) async {
    setState(() {
      _loadingImage = true;
    });
    var imageData = img.decodeImage(await imageFile!.readAsBytes());

    if (width == 0) width = MediaQuery.of(context).size.width;
    var coefficient = width / imageData!.width;

    previewData = img.copyResize(imageData,
        width: width.toInt(), height: (imageData.height * coefficient).toInt());

    setState(() {
      imagePreview = Uint8List.fromList(img.encodeJpg(previewData!));
      _loadingImage = false;
    });
  }

  Future invertPreview() async {
    setState(() {
      _loadingInverted = true;
    });

    var invertedPreview = invertImage(previewData!.clone(), inversionCoefficient());

    return setState(() {
      invertedImagePreview = Uint8List.fromList(img.encodeJpg(invertedPreview));
      _loadingInverted = false;
    });
  }

  void exportInvertedImage() async {
    try {
      context.loaderOverlay.show();

      setState(() {
        _exportingInverted = true;
      });

      var imageData = img.decodeImage(await imageFile!.readAsBytes());
      var invertedData = invertImage(imageData!, inversionCoefficient());
      var invertedJpeg = Uint8List.fromList(img.encodeJpg(invertedData));

      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String filePath = '$tempPath/__pictureVertInvertedImage.jpg';

      File outputFile = File(filePath);
      await outputFile.writeAsBytes(invertedJpeg);

      await Share.shareFilesWithResult([filePath], text: 'Inverted picture').then((
          value) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Converted image exported'),
            )
        );
      });
    }
    catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed'),
          )
      );
    }
    finally {
      setState(() {
        _exportingInverted = false;
      });
      context.loaderOverlay.hide();
    }
  }

  void _loadedImage(XFile? image) async {
    try {
      if (image == null) return;

      context.loaderOverlay.show();

      setState(() {
        _resetImages();
      });

      imageFile = File(image.path);

      await buildPreview();
      await invertPreview();
    } finally {
      context.loaderOverlay.hide();
    }
  }

  Widget _placeholder(Uint8List? imageDataHolder, bool isLoading, {emptyText=""}) {
    if (imageDataHolder != null) {
      return Image.memory(imageDataHolder, fit: BoxFit.cover);
    }

    if (isLoading) {
      return Container(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: const [CircularProgressIndicator()],
            mainAxisAlignment: MainAxisAlignment.center,
          ));
    }

    return Row(
      children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
              emptyText,
              style: const TextStyle(fontSize: 22, color: Colors.indigo),
            textAlign: TextAlign.center,
          )
        )
        )
      ],
    );
    // return const SizedBox(width: 0, height: 0);
  }

  Widget _slider() {
    if (imagePreview == null) {
      return const SizedBox(width: 0, height: 0);
    }

    return Slider(
        value: _inversionRangeSliderValue,
        max: 100,
        min: -100,
        // divisions: 50,
        label: _inversionRangeSliderValue.round().toString(),
        onChanged: invertedImagePreview != null
            ? (double value) {
          setState(() {
            _loadingInverted = true;
            _inversionRangeSliderValue = value;
          });
        }
            : null,
        onChangeEnd: (double value) {
          // setState(() {
          invertPreview().then((value) {
            if (_scrollController.offset != 500) {
              _scrollController.animateTo(500,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn);
            }
          });
          // });
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
      body: ListView(
        controller: _scrollController,
        cacheExtent: 5000,
        // physics: _loadingInverted ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _placeholder(
              imagePreview,
              _loadingImage,
              emptyText: "Pick photo from the library or take a picture to convert"
          ),
          _slider(),
          // Image.memory(invertedImagePreview!, fit: BoxFit.cover),
          _placeholder(invertedImagePreview, _loadingInverted),
        ],
      ),
      persistentFooterButtons: [
        Row(
          children: [
            IconButton(
              onPressed: () async {
                context.loaderOverlay.show();
                final XFile? image =
                    await _picker.pickImage(source: ImageSource.camera);
                _loadedImage(image);
              },
              color: Colors.indigoAccent,
              icon: const Icon(
                Icons.camera_alt_rounded,
                size: 30.0,
              ),
              tooltip: 'Take a photo',
            ),
            IconButton(
              onPressed: () async {
                context.loaderOverlay.show();
                final XFile? image =
                    await _picker.pickImage(source: ImageSource.gallery);
                _loadedImage(image);
                // Respond to button press
              },
              tooltip: 'Open image',
              color: Colors.indigoAccent,
              icon: const Icon(Icons.image_rounded, size: 30.0),
            ),
            IconButton(
              onPressed: invertedImagePreview != null ? exportInvertedImage : null,
              tooltip: "Export image",
              color: Colors.indigoAccent,
              icon: const Icon(Icons.save_alt_outlined, size: 30.0),
            )
          ],
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        )
      ],
    );
  }
}
