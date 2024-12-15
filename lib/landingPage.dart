import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picturevert/src/actions.dart';
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

  double _smudgeRangeSliderValue = 50;
  double _smudgeLineSizeSliderValue = 1;
  Direction _actionDirection = Direction.right;

  double _jitterSliderValue = 0;

  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: true);

  late final TabController _tabController;

  bool _loadingImage = false;
  bool _loadingProcessed = false;
  bool _exportingProcessed = false;
  int _tabIndex = 0;

  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  img.Image? previewData;
  Uint8List? imagePreview;
  Uint8List? resultImagePreview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _resetPreview();
        _tabIndex = _tabController.index;
      });
      generatePreview();
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

  void _resetPreview() {
    resultImagePreview = null;
    _inversionRangeSliderValue = 0;
    _smudgeRangeSliderValue = 50;
    _smudgeLineSizeSliderValue = 1;
    _actionDirection = Direction.right;
  }

  void _resetImages() {
    imageFile = null;
    previewData = null;
    imagePreview = null;
    _resetPreview();
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

  Future generatePreview() async {
    if (imagePreview == null) {
      return;
    }

    setState(() {
      _loadingProcessed = true;
    });

    final action = currentAction(_tabIndex);

    var pendingPreview = previewData!.clone();

    if (action == ActionType.invert) {
      pendingPreview = ImageTools.invertImage(
          src: previewData!.clone(), shiftCoefficient: inversionCoefficient());
    }
    if (action == ActionType.smudge) {
      pendingPreview = ImageTools.smudgeImage(
          src: previewData!.clone(),
          smudgeStartPct: _smudgeRangeSliderValue,
          direction: _actionDirection,
          lineSize: _smudgeLineSizeSliderValue,
          jitter: _jitterSliderValue);
    }
    if (action == ActionType.mirror) {
      pendingPreview = ImageTools.mirrorImage(
          src: previewData!.clone(), direction: _actionDirection);
    }

    return setState(() {
      resultImagePreview = Uint8List.fromList(img.encodeJpg(pendingPreview));
      _loadingProcessed = false;
    });
  }

  void exportConvertedImage() async {
    try {
      setState(() {
        _exportingProcessed = true;
      });

      final imageData = img.decodeImage(await imageFile!.readAsBytes());
      final action = currentAction(_tabIndex);

      var convertedData = imageData!;

      if (action == ActionType.invert) {
        convertedData = ImageTools.invertImage(
            src: imageData, shiftCoefficient: inversionCoefficient());
      }
      if (action == ActionType.smudge) {
        convertedData = ImageTools.smudgeImage(
            src: imageData,
            smudgeStartPct: _smudgeRangeSliderValue,
            direction: _actionDirection,
            lineSize: _smudgeLineSizeSliderValue,
            jitter: _jitterSliderValue);
      }
      if (action == ActionType.mirror) {
        convertedData =
            ImageTools.mirrorImage(src: imageData, direction: _actionDirection);
      }

      var convertedJpeg = Uint8List.fromList(img.encodeJpg(convertedData));

      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String filePath = '$tempPath/__pictureVertConvertedImage.jpg';

      File outputFile = File(filePath);
      await outputFile.writeAsBytes(convertedJpeg);

      final Size size = MediaQuery.of(context).size;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Converted picture',
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
        _exportingProcessed = false;
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
      await generatePreview();
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

  Widget _directionGroup() {
    onChanged(Direction value) {
      setState(() {
        _actionDirection = value;
        generatePreview();
      });
    }

    return Column(children: [
      Row(
          // mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: Text("")),
            Radio<Direction>(
                value: Direction.right,
                groupValue: _actionDirection,
                onChanged: (value) => onChanged(value!)),
            Text("R"),
            Expanded(child: Text("")),
            Radio<Direction>(
              value: Direction.left,
              groupValue: _actionDirection,
              onChanged: (value) => onChanged(value!),
            ),
            Text("L"),
            Expanded(child: Text("")),
            Radio<Direction>(
              value: Direction.up,
              groupValue: _actionDirection,
              onChanged: (value) => onChanged(value!),
            ),
            Text("U"),
            Expanded(child: Text("")),
            Radio<Direction>(
              value: Direction.down,
              groupValue: _actionDirection,
              onChanged: (value) => onChanged(value!),
            ),
            Text("D"),
            Expanded(child: Text("")),
          ])
    ]);
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
    final action = currentAction(_tabIndex);
    final configuration = [];

    if (action == ActionType.invert) {
      configuration.add(_inversionSlider());
    }
    if (action == ActionType.smudge) {
      configuration.add(_smudgeSlider());
      configuration.add(_smudgeLineSizeSlider());
      configuration.add(_jitterSlider());
      configuration.add(_directionGroup());
    }
    if (action == ActionType.mirror) {
      configuration.add(_directionGroup());
    }

    return [
      ...configuration,
      _placeholder(resultImagePreview, _loadingProcessed),
    ];
  }

  void _sliderPostScroll(double value) {
    // Dirty brown magic to return the screen to the same position.
    // For some reason just scrolling back to previous position doesn't work,
    // so this trick is to scroll down and then back to where it was.
    var scrollPosition = _scrollController.offset;
    generatePreview().then((value) {
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
  }

  Widget _inversionSlider() {
    return genericSlider(
        Icons.monochrome_photos,
        Slider(
            value: _inversionRangeSliderValue,
            max: 100,
            min: -100,
            // divisions: 50,
            label: _inversionRangeSliderValue.round().toString(),
            onChanged: resultImagePreview != null
                ? (double value) {
                    setState(() {
                      _loadingProcessed = true;
                      _inversionRangeSliderValue = value;
                    });
                  }
                : null,
            onChangeEnd: _sliderPostScroll));
  }

  Widget genericSlider(IconData sliderIcon, Widget specificSlider) {
    if (imagePreview == null) {
      return const SizedBox(width: 0, height: 0);
    }

    return Row(children: [
      Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Icon(
            sliderIcon,
            size: 30.0,
          )),
      Expanded(child: specificSlider)
    ]);
  }

  Widget _smudgeSlider() {
    return genericSlider(
        Icons.image_not_supported,
        Slider(
            value: _smudgeRangeSliderValue,
            max: 99,
            min: 1,
            // divisions: 50,
            label: _smudgeRangeSliderValue.round().toString(),
            onChanged: resultImagePreview != null
                ? (double value) {
                    setState(() {
                      _loadingProcessed = true;
                      _smudgeRangeSliderValue = value;
                    });
                  }
                : null,
            onChangeEnd: _sliderPostScroll));
  }

  Widget _jitterSlider() {
    return genericSlider(
        Icons.waves,
        Slider(
            value: _jitterSliderValue,
            max: 50,
            min: 0,
            // divisions: 50,
            label: _jitterSliderValue.round().toString(),
            onChanged: resultImagePreview != null
                ? (double value) {
                    setState(() {
                      _loadingProcessed = true;
                      _jitterSliderValue = value;
                    });
                  }
                : null,
            onChangeEnd: _sliderPostScroll));
  }

  Widget _smudgeLineSizeSlider() {
    return genericSlider(
        Icons.format_size,
        Slider(
            value: _smudgeLineSizeSliderValue,
            max: 500,
            min: 1,
            // divisions: 50,
            label: _smudgeLineSizeSliderValue.round().toString(),
            onChanged: resultImagePreview != null
                ? (double value) {
                    setState(() {
                      _loadingProcessed = true;
                      _smudgeLineSizeSliderValue = value;
                    });
                  }
                : null,
            onChangeEnd: _sliderPostScroll));
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
              onPressed: resultImagePreview != null
                  ? () {
                      context.loaderOverlay.show();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        exportConvertedImage();
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
