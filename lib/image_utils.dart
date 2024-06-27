import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imageLib;

/// ImageUtils
class ImageUtils {
  static int count = 0;

  static imageLib.Image resize(
      imageLib.Image src, int expectWidh, int expectHeight) {
    double imageRatio = src.width / src.height;
    double expectSizeRatio = expectWidh / expectHeight;
    if (imageRatio < expectSizeRatio) {
      // resize follow width
      // expectWidh = 480;
      expectHeight = (expectWidh * (src.height / src.width)).round();
    } else {
      // resize follow height
      // expectWidh = 640;
      expectWidh = (expectHeight * (src.width / src.height)).round();
    }
    return imageLib.copyResize(src, width: expectWidh, height: expectHeight);
  }

  /// Converts a [CameraImage] in YUV420 format to [imageLib.Image] in RGB format
  static imageLib.Image? convertCameraImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV420ToImage1(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImage(cameraImage);
    } else {
      return null;
    }
  }

  /// Converts a [CameraImage] in BGRA888 format to [imageLib.Image] in RGB format
  static imageLib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
    int width = cameraImage.width;
    int height = cameraImage.height;
    var planes = cameraImage.planes;

    final rgbBytes = Uint8List(width * height * 3);

    // Chỉ xử lý plane đầu tiên (plane 0)
    final planeData = planes[0].bytes;
    int byteIndex = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int pixelIndex =
            y * planes[0].bytesPerRow + x * 4; // 4 bytes per pixel (BGRA)
        rgbBytes[byteIndex++] = planeData[pixelIndex]; // B
        rgbBytes[byteIndex++] = planeData[pixelIndex + 1]; // G
        rgbBytes[byteIndex++] = planeData[pixelIndex + 2]; // R
        // Bỏ qua byte alpha (A)
      }
    }

    return imageLib.Image.fromBytes(
      width,
      height,
      rgbBytes,
      format: imageLib.Format.rgb,
    );
  }

  /// Converts a [CameraImage] in YUV420 format to [imageLib.Image] in RGB format
  static imageLib.Image convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = imageLib.Image(width, height);

    int tmpIndex = 0, tmpUVIndex = 0;

    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final int uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;

        tmpIndex = index;
        tmpUVIndex = uvIndex;

        final y = cameraImage.planes[0].bytes[index];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        int a = ImageUtils.yuv2rgb(y, u, v);

        // print(index);
        // print(a);
        image.data[index] = a;
      }
    }
    return image;
  }

  /// Converts a [CameraImage] in YUV420 format to [imageLib.Image] in RGB format new way
  static imageLib.Image convertYUV420ToImage1(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = imageLib.Image(imageWidth, imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        // Y plane should have positive values belonging to [0...255]
        final int y = yBuffer[yIndex];

        // U/V Values are subsampled i.e. each pixel in U/V chanel in a
        // YUV_420 image act as chroma value for 4 neighbouring pixels
        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
        // [0, 255] range they are scaled up and centered to 128.
        // Operation below brings U/V values to [-128, 127].
        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        // Compute RGB values per formula above.
        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        // Use 255 for alpha value, no transparency. ARGB values are
        // positioned in each byte of a single 4 byte integer
        // [AAAAAAAARRRRRRRRGGGGGGGGBBBBBBBB]
        final int argbIndex = h * imageWidth + w;

        image.data[argbIndex] = 0xff000000 |
            ((b << 16) & 0xff0000) |
            ((g << 8) & 0xff00) |
            (r & 0xff);
      }
    }

    return image;
  }

  /// Convert a single YUV pixel to RGB
  static int yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    int r = (y + v * 1436 / 1024 - 179).round();
    int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    int b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    if (count < 15) {
      print("check rgb r = $r g = $g b = $b");
      count++;
    }
    return 0xff000000 |
        ((b << 16) & 0xff0000) |
        ((g << 8) & 0xff00) |
        (r & 0xff);
  }
}

imageLib.Image convertYUV420(CameraImage cameraImage) {
  final int? width = cameraImage.width;
  final int? height = cameraImage.height;

  final int? uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;

  final image = imageLib.Image(width!, height!);

  for (int w = 0; w < width; w++) {
    for (int h = 0; h < height; h++) {
      final int uvIndex =
          uvPixelStride! * (w / 2).floor() + uvRowStride! * (h / 2).floor();
      final int index = h * width + w;

      final y = cameraImage.planes[0].bytes[index];
      final u = cameraImage.planes[1].bytes[uvIndex];
      final v = cameraImage.planes[2].bytes[uvIndex];

      image.data[index] = yuv2rgb(y, u, v);
    }
  }
  return image;
}

int yuv2rgb(int y, int u, int v) {
  // Convert yuv pixel to rgb
  int r = (y + v * 1436 / 1024 - 179).round();
  int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
  int b = (y + u * 1814 / 1024 - 227).round();

  // Clipping RGB values to be inside boundaries [ 0 , 255 ]
  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);

  return 0xff000000 | ((b << 16) & 0xff0000) | ((g << 8) & 0xff00) | (r & 0xff);
}
