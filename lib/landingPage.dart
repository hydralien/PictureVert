import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picturevert/src/image_tools.dart';
import 'package:share_plus/share_plus.dart';

class PVPage extends StatefulWidget {
  const PVPage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<PVPage> createState() => _PVPageState();
}

class _PVPageState extends State<PVPage> with TickerProviderStateMixin {
  double _inversionRangeSliderValue = 0;

  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: true);

  late final TabController _tabController;

  bool _loadingImage = false;
  bool _loadingInverted = false;
  bool _exportingInverted = false;
  int _tabIndex = 0;

  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  img.Image? previewData;
  Uint8List? imagePreview;
  Uint8List? invertedImagePreview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _tabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Future buildPreview({double width = 0}) async {
    setState(() {
      _loadingImage = true;
    });
    var imageData = img.decodeImage(await imageFile!.readAsBytes());

    if (width == 0) width = MediaQuery.of(context).size.width;
    width *= 1.5;
    var coefficient = width / imageData!.width;

    previewData = img.copyResize(imageData,
        width: width.toInt(),
        height: (imageData.height * coefficient).toInt(),
        interpolation: img.Interpolation.average);

    setState(() {
      imagePreview = Uint8List.fromList(img.encodeJpg(previewData!));
      _loadingImage = false;
    });
  }

  Future invertPreview() async {
    setState(() {
      _loadingInverted = true;
    });

    var invertedPreview =
        ImageTools.invertImage(previewData!.clone(), inversionCoefficient());

    return setState(() {
      invertedImagePreview = Uint8List.fromList(img.encodeJpg(invertedPreview));
      _loadingInverted = false;
    });
  }

  void exportInvertedImage() async {
    try {
      setState(() {
        _exportingInverted = true;
      });

      var imageData = img.decodeImage(await imageFile!.readAsBytes());
      var invertedData =
          ImageTools.invertImage(imageData!, inversionCoefficient());
      var invertedJpeg = Uint8List.fromList(img.encodeJpg(invertedData));

      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String filePath = '$tempPath/__pictureVertInvertedImage.jpg';

      File outputFile = File(filePath);
      await outputFile.writeAsBytes(invertedJpeg);

      final Size size = MediaQuery.of(context).size;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Inverted picture',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
      ).then((value) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Converted image exported'),
        ));
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export failed'),
      ));
    } finally {
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

  Widget _placeholder(Uint8List? imageDataHolder, bool isLoading,
      {emptyText = ""}) {
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
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  emptyText,
                  style: const TextStyle(fontSize: 22, color: Colors.indigo),
                  textAlign: TextAlign.center,
                )))
      ],
    );
    // return const SizedBox(width: 0, height: 0);
  }

  Widget _actionTabs() {
    return Column(children: [
      TabBar(
        controller: _tabController,
        tabs: const <Widget>[
          Tab(
            icon: Icon(Icons.monochrome_photos),
          ),
          Tab(
            icon: Icon(Icons.image_not_supported),
          ),
          Tab(
            icon: Icon(Icons.star_half),
          ),
        ],
      ),
    ]);
  }

  List<Widget> _actionTabContent() {
    if (_tabIndex == 0) {
      return [
        _slider(),
        // Image.memory(invertedImagePreview!, fit: BoxFit.cover),
        _placeholder(invertedImagePreview, _loadingInverted),
      ];
    }
    return [Icon(Icons.brightness_5_sharp)];
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
          // Dirty brown magic to return the screen to the same position.
          // For some reason just scrolling back to previous position doesn't work,
          // so this trick is to scroll down and then back to where it was.
          var scrollPosition = _scrollController.offset;
          invertPreview().then((value) {
            _scrollController
                .animateTo(500,
                    duration: const Duration(milliseconds: 1),
                    curve: Curves.fastOutSlowIn)
                .then((value) => {
                      _scrollController.animateTo(scrollPosition,
                          duration: const Duration(milliseconds: 1),
                          curve: Curves.fastOutSlowIn)
                    });
          });
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
          _placeholder(imagePreview, _loadingImage,
              emptyText:
                  "Pick photo from the library or take a picture to convert"),
          _actionTabs(),
          ..._actionTabContent(),
        ],
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
              onPressed: invertedImagePreview != null
                  ? () {
                      context.loaderOverlay.show();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        exportInvertedImage();
                      });
                    }
                  : null,
              tooltip: "Export image",
              color: Colors.indigoAccent,
              icon: const Icon(Icons.save_alt_outlined, size: 30.0),
            )
          ],
        )
      ],
    );
  }
}
