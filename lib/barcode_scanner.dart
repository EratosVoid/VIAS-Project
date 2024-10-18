import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BarcodeScannerPage extends StatefulWidget {
  final CameraController cameraController;

  BarcodeScannerPage({required this.cameraController});

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with WidgetsBindingObserver {
  bool isScanning = false;
  bool isBusy = false;
  late BarcodeScanner barcodeScanner;
  CameraImage? img;
  late FlutterTts flutterTts;
  String _barcode = 'Unknown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    flutterTts = FlutterTts();
    barcodeScanner = BarcodeScanner();
  }

  @override
  void dispose() {
    print('barcode dispose');
    WidgetsBinding.instance.removeObserver(this);
    stopImageStream();
    barcodeScanner.close();
    flutterTts.stop();
    super.dispose();
  }

  void startImageStream() {
    widget.cameraController.startImageStream((image) {
      if (!isBusy) {
        isBusy = true;
        img = image;
        doBarcodeScanning();
      }
    });
  }

  void stopImageStream() {
    try {
      widget.cameraController.stopImageStream();
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!isBusy) startImageStream();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stopImageStream();
    }
  }


  void doBarcodeScanning() async {
    final InputImage? inputImage = getInputImage();
    if (inputImage == null) {
      isBusy = false;
      return;
    }

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null && barcode.rawValue != '') {
          print('barcode setstate');
          if(mounted){
            setState(() {
              _barcode = barcode.rawValue!;
            });
          }
          await _getProductInfo(barcode.rawValue!);
          // After scanning, stop the image stream and reset the scanning state
          stopImageStream();
          if(mounted){
            setState(() {
              isScanning = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error during barcode scanning: $e');
    }

    isBusy = false;
  }

  Future<void> _getProductInfo(String barcode) async {
    try {
      var response = await http.get(
        Uri.parse('https://api.barcodelookup.com/v3/products?barcode=$barcode&key=236a3ai19rn348bxcoqukrgrt5vdp0'),
      );

      if (response.statusCode == 200) {
        var productData = jsonDecode(response.body);

        if (productData != null && productData['products'] != null && productData['products'].isNotEmpty) {
          String productTitle = productData['products'][0]['title'];
          await _announceProduct(productTitle);
        } else {
          await _announceProduct('Product not found');
        }
      } else {
        await _announceProduct('Error retrieving product information');
      }
    } catch (e) {
      await _announceProduct('Error retrieving product information');
    }
  }

  Future<void> _announceProduct(String product) async {
    await flutterTts.speak("The product in front of you is $product.");
  }

  InputImage? getInputImage() {
    try {
      final BytesBuilder bytesBuilder = BytesBuilder();
      for (Plane plane in img!.planes) {
        bytesBuilder.add(plane.bytes);
      }
      final bytes = bytesBuilder.toBytes();

      final imageSize = Size(img!.width.toDouble(), img!.height.toDouble());

      final imageRotation = _rotationIntToImageRotation(
        widget.cameraController.description.sensorOrientation,
      );

      // Determine the image format based on the platform
      final inputImageFormat = Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      // Get bytesPerRow from the first plane
      final bytesPerRow = img!.planes.first.bytesPerRow;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      return inputImage;
    } catch (e) {
      print("Error creating InputImage: $e");
      return null;
    }
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        throw Exception('Invalid rotation value: $rotation');
    }
  }

  void _onScanBarcodeButtonPressed() {
    if(mounted){
      setState(() {
        print('barcode setstate');
        isScanning = true;
      });
    }
    startImageStream();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (isScanning) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Scanning Barcode...'),
        ),
        body: widget.cameraController.value.isInitialized
            ? Stack(
          children: [
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: CameraPreview(widget.cameraController),
            ),
            // You can add code to display scanning overlay here
          ],
        )
            : Center(child: CircularProgressIndicator()),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text('Barcode Scanner'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _onScanBarcodeButtonPressed,
            child: Text('Scan Barcode'),
          ),
        ),
      );
    }
  }
}
