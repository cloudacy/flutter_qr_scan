import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// The resulting object, when calling `FlutterNativeBarcodeScanner.start()`.
///
/// This object holds camera preview details: textureId for the `Texture` widget, texture `width` and `height` in pixels.
class FlutterNativeBarcodeScannerTexture {
  /// The id to be used at a `Texture` widget.
  /// ```dart
  /// Texture(textureId: texture.id)
  /// ```
  final int id;

  /// Holds the texture width in pixels. Can be null.
  final double? width;

  /// Holds the texture height in pixels. Can be null.
  final double? height;

  const FlutterNativeBarcodeScannerTexture._({
    required this.id,
    required this.width,
    required this.height,
  });
}

/// This class allows to start and stop the barcode scan process,
/// by using the static `start()` and `stop()` methods.
///
/// It also allows to receive barcodes, by calling `getCode()`.
class FlutterNativeBarcodeScanner {
  static const MethodChannel _channel = MethodChannel('flutter_native_barcode_scanner');

  static StreamController<Object?>? _controller;

  /// Creates a new code stream and tries to start the barcode scan.
  ///
  /// May throw a `PlatformException`.
  static Future<FlutterNativeBarcodeScannerTexture?> start() async {
    // Create a new StreamController to receive codes from the platform.
    // ignore: close_sinks
    final controller = StreamController<Object?>();

    // Assign the new controller to the static variable.
    _controller = controller;

    // Add a method call handler to add received codes to the StreamController.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'code') {
        controller.add(call.arguments);
      }
    });

    // Invoke the "start" platform method and return the result.
    final result = await _channel.invokeMapMethod<String, Object?>('start');
    if (result == null) {
      return null;
    }

    // Check the textureId.
    final textureId = result['textureId'];
    if (!(textureId is int)) {
      return null;
    }

    return FlutterNativeBarcodeScannerTexture._(
      id: textureId,
      width: (result['previewWidth'] as num?)?.toDouble(),
      height: (result['previewHeight'] as num?)?.toDouble(),
    );
  }

  /// Stops a currently running barcode scan.
  static Future<bool> stop() async {
    // Check if a barcode scan is running.
    final controller = _controller;
    if (controller == null) {
      return false;
    }

    // Close the stream controller, since we no receive any barcodes.
    controller.close();
    _controller = null;

    // Invoke the "stop" platform method.
    return (await _channel.invokeMethod<bool>('stop')) ?? false;
  }

  /// Wait for a barcode to be returned by the platform.
  ///
  /// Returns `null` if no code got sent from the platform (e.g. the process got canceled)
  /// or if the barcode scan process is not running.
  static Future<Object?> getBarcode() {
    final stream = _controller?.stream;
    if (stream == null) {
      return Future.value(null);
    }

    try {
      return stream.first;
    } catch (_) {
      return Future.value(null);
    }
  }
}

/// [FlutterNativeBarcodeScannerPreview] provides an easy option to render a camera preview.
/// Provide an aspectRatio to optionally crop the preview to given aspect ratio.
class FlutterNativeBarcodeScannerPreview extends StatelessWidget {
  final FlutterNativeBarcodeScannerTexture _texture;

  /// Optional cropped aspect ratio. If set, the preview gets cropped to given aspect ratio.
  final double? aspectRatio;

  /// Create a new [FlutterNativeBarcodeScannerPreview] instance.
  ///
  /// Requires a [FlutterNativeBarcodeScannerTexture] to render the preview to the screen.
  ///
  /// Provide an optional `aspectRatio` to define a custom cropped preview aspect ratio.
  const FlutterNativeBarcodeScannerPreview({
    Key? key,
    required FlutterNativeBarcodeScannerTexture texture,
    this.aspectRatio,
  })  : _texture = texture,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    if (aspectRatio == null) {
      return AspectRatio(
        aspectRatio: (_texture.height ?? 1) / (_texture.width ?? 1),
        child: Texture(
          textureId: _texture.id,
        ),
      );
    }

    final size = MediaQuery.of(context).size.width;
    return Container(
      width: size,
      height: size / aspectRatio!,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Container(
              width: size,
              height: size / ((_texture.height ?? 1) / (_texture.width ?? 1)),
              child: Texture(textureId: _texture.id),
            ),
          ),
        ),
      ),
    );
  }
}
