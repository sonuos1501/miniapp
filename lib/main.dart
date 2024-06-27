import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraApp(),
    );
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? imageFile;
  CameraImage? currentImage;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    // Lấy danh sách các camera có sẵn
    final cameras = await availableCameras();
    // Chọn camera sau
    final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);

    // Khởi tạo bộ điều khiển camera
    _controller = CameraController(firstCamera!,
        Platform.isAndroid ? ResolutionPreset.max : ResolutionPreset.veryHigh,
        imageFormatGroup: ImageFormatGroup.bgra8888, enableAudio: false);
    // Bắt đầu camera
    _controller.initialize().then((_) {
      setState(() {});
    });

    _controller.startImageStream((image) {
      currentImage = image;
    });
  }

  @override
  void dispose() {
    // Giải phóng bộ điều khiển camera khi widget bị hủy
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Hiển thị camera preview
            return imageFile == null
                ? CameraPreview(_controller)
                : Image.file(File(imageFile!.path));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        onPressed: () async {
          if (imageFile != null) {
            imageFile = null;
            setState(() {});
            return;
          }
          // Chụp ảnh
          try {
            // Chụp ảnh
            // XFile image = await _controller.takePicture();
            final yuvBytes = currentImage!.planes[0].bytes;
            // Store image in temp directory
            final directory = await getTemporaryDirectory();
            final file = File('${directory.path}/tempImage.jpg');
            await file.writeAsBytes(yuvBytes);
            // Lưu ảnh vào bộ nhớ
            imageFile = XFile(file.path);
            setState(() {});
            // Hiển thị thông báo
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Đã chụp ảnh')));
          } catch (e) {
            print('Lỗi khi chụp ảnh: ${e.toString()}');
          }
        },
      ),
    );
  }
}
