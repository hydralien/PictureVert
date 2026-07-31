import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picturevert/src/actions.dart';
import 'package:picturevert/src/image_tools.dart';
import 'package:share_plus/share_plus.dart';

class PVPage extends StatefulWidget {
  const PVPage({super.key, required this.title});

  final String title;

  @override
  State<PVPage> createState() => _PVPageState();
}

class _PVPageState extends State<PVPage> with TickerProviderStateMixin {
  double _inversionRangeSliderValue = 0;

  double _smudgeRangeSliderValue = 50;
  double _smudgeLineSizeSliderValue = 1;
  Direction _actionDirection = Direction.right;
  Direction _secondaryActionDirection = Direction.none;

  double _jitterSliderValue = 0;

  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: true);

  late final TabController _tabController;

  bool _loadingImage = false;
  bool _loadingProcessed = false;
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
      if (_tabController.indexIsChanging) {
        return;
      }
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
    _jitterSliderValue = 0;
    _actionDirection = Direction.right;
    _secondaryActionDirection = Direction.none;
  }

  void _resetImages() {
    imageFile = null;
    previewData = null;
    imagePreview = null;
    _resetPreview();
  }

  Future buildPreview({double width = 0}) async {
    setState(() {
      _loadingImage = true;
    });
    var imageData = img.decodeImage(await imageFile!.readAsBytes());

    if (width == 0 && mounted) width = MediaQuery.of(context).size.width;
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
          src: previewData!.clone(),
          direction: _actionDirection,
          secondaryDirection: _secondaryActionDirection);
    }

    return setState(() {
      resultImagePreview = Uint8List.fromList(img.encodeJpg(pendingPreview));
      _loadingProcessed = false;
    });
  }

  void exportConvertedImage() async {
    final overlay = context.loaderOverlay;
    try {
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
        convertedData = ImageTools.mirrorImage(
            src: imageData,
            direction: _actionDirection,
            secondaryDirection: _secondaryActionDirection);
      }

      var convertedJpeg = Uint8List.fromList(img.encodeJpg(convertedData));

      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String filePath = '$tempPath/__pictureVertConvertedImage.jpg';

      File outputFile = File(filePath);
      await outputFile.writeAsBytes(convertedJpeg);

      if (!mounted) return;
      final Size size = MediaQuery.of(context).size;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Converted picture',
          sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Converted image exported'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export failed'),
      ));
    } finally {
      overlay.hide();
    }
  }

  void _loadedImage(XFile? image) async {
    final overlay = context.loaderOverlay;
    try {
      if (image == null) return;

      setState(() {
        _resetImages();
      });

      imageFile = File(image.path);

      await buildPreview();
      await generatePreview();
    } finally {
      overlay.hide();
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator()],
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
  }

  Widget _directionGroup() {
    if (imagePreview == null) {
      return const SizedBox(width: 0, height: 0);
    }

    onChanged(Direction value) {
      setState(() {
        _actionDirection = value;
        generatePreview();
        _sliderPostScroll(0);
      });
    }

    return Column(children: [
      RadioGroup<Direction>(
        groupValue: _actionDirection,
        onChanged: (value) => onChanged(value!),
        child: Row(children: [
          const Expanded(child: Text("")),
          Radio<Direction>(value: Direction.right),
          const Text("R"),
          const Expanded(child: Text("")),
          Radio<Direction>(value: Direction.left),
          const Text("L"),
          const Expanded(child: Text("")),
          Radio<Direction>(value: Direction.up),
          const Text("U"),
          const Expanded(child: Text("")),
          Radio<Direction>(value: Direction.down),
          const Text("D"),
          const Expanded(child: Text("")),
        ]),
      )
    ]);
  }

  Widget _secondaryDirectionGroup() {
    if (imagePreview == null) {
      return const SizedBox(width: 0, height: 0);
    }

    onChanged(Direction value) {
      setState(() {
        _secondaryActionDirection = value;
        generatePreview();
        _sliderPostScroll(0);
      });
    }

    List<Widget> secondDirectionComponents = [
      Radio<Direction>(value: Direction.right),
      const Text("R"),
      const Expanded(child: Text("")),
      Radio<Direction>(value: Direction.left),
      const Text("L"),
      const Expanded(child: Text("")),
    ];

    if (_actionDirection == Direction.right ||
        _actionDirection == Direction.left) {
      secondDirectionComponents = [
        Radio<Direction>(value: Direction.up),
        const Text("U"),
        const Expanded(child: Text("")),
        Radio<Direction>(value: Direction.down),
        const Text("D"),
        const Expanded(child: Text("")),
      ];
    }

    return Column(children: [
      RadioGroup<Direction>(
        groupValue: _secondaryActionDirection,
        onChanged: (value) => onChanged(value!),
        child: Row(children: [
          const Expanded(child: Text("")),
          const Text("2nd:", style: TextStyle(fontWeight: FontWeight.bold)),
          const Expanded(child: Text("")),
          Radio<Direction>(value: Direction.none),
          const Text("None"),
          const Expanded(child: Text("")),
          ...secondDirectionComponents
        ]),
      )
    ]);
  }

  Widget _actionTabs() {
    return Column(children: [
      IgnorePointer(
          ignoring: imagePreview == null,
          child: TabBar(
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
          )),
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
      configuration.add(_secondaryDirectionGroup());
    }

    return [
      ...configuration,
      _placeholder(resultImagePreview, _loadingProcessed),
    ];
  }

  void _sliderPostScroll(double value) {
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
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        controller: _scrollController,
        scrollCacheExtent: ScrollCacheExtent.pixels(5000),
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
