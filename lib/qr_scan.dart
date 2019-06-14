// import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// final MethodChannel _channel = const MethodChannel('io.cloudacy.qr_scan')..invokeMethod('init');

class QrScan extends StatefulWidget {
  @override
  _QrScanState createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  static const MethodChannel _channel = const MethodChannel('io.cloudacy.qr_scan');
  bool running = false;
  int textureId;

  @override
  void initState() {
    super.initState();

    // First get available cameras.
    // Then invoke the initialize method with the id of the chosen camera.

    prepareCamera();
  }

  void prepareCamera() async {
    final dynamic data = await _channel.invokeMethod('init', <String, dynamic>{'cameraId': 'test'});
    print(data.toString());
    //setState(() {
    //  textureId = data['textureId'];
    //});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (textureId != null && running)
          Expanded(
            child: Texture(textureId: textureId),
          ),
        RaisedButton(
          child: Text('start'),
          onPressed: () async {
            await _channel.invokeMethod('start');
            print('started');
            setState(() {
              running = true;
            });
          },
        ),
      ],
    );
  }
}
/*
enum CameraLensDirection { front, back, external }
enum CodeFormat { codabar, code39, code93, code128, ean8, ean13, itf, upca, upce, aztec, datamatrix, pdf417, qr }
enum ResolutionPreset { low, medium, high }

var _availableFormats = {
  CodeFormat.codabar: 'codabar', // Android only
  CodeFormat.code39: 'code39',
  CodeFormat.code93: 'code93',
  CodeFormat.code128: 'code128',
  CodeFormat.ean8: 'ean8',
  CodeFormat.ean13: 'ean13',
  CodeFormat.itf: 'itf', // itf-14 on iOS, should be changed to Interleaved2of5?
  CodeFormat.upca: 'upca', // Android only
  CodeFormat.upce: 'upce',
  CodeFormat.aztec: 'aztec',
  CodeFormat.datamatrix: 'datamatrix',
  CodeFormat.pdf417: 'pdf417',
  CodeFormat.qr: 'qr',
};

/// Returns the resolution preset as a String.
String serializeResolutionPreset(ResolutionPreset resolutionPreset) {
  switch (resolutionPreset) {
    case ResolutionPreset.high:
      return 'high';
    case ResolutionPreset.medium:
      return 'medium';
    case ResolutionPreset.low:
      return 'low';
  }
  throw new ArgumentError('Unknown ResolutionPreset value');
}

List<String> serializeCodeFormatsList(List<CodeFormat> formats) {
  List<String> list = [];

  for (var i = 0; i < formats.length; i++) {
    if (_availableFormats[formats[i]] != null) {
      //  this format exists in my list of available formats
      list.add(_availableFormats[formats[i]]);
    }
  }

  return list;
}

CameraLensDirection _parseCameraLensDirection(String string) {
  switch (string) {
    case 'front':
      return CameraLensDirection.front;
    case 'back':
      return CameraLensDirection.back;
    case 'external':
      return CameraLensDirection.external;
  }
  throw new ArgumentError('Unknown CameraLensDirection value');
}

/// Completes with a list of available cameras.
///
/// May throw a [QRReaderException].
Future<List<CameraDescription>> availableCameras() async {
  try {
    final List<dynamic> cameras = await _channel.invokeMethod('availableCameras');
    return cameras.map((dynamic camera) {
      return new CameraDescription(
        name: camera['name'],
        lensDirection: _parseCameraLensDirection(camera['lensFacing']),
      );
    }).toList();
  } on PlatformException catch (e) {
    throw new QRReaderException(e.code, e.message);
  }
}

/// This is thrown when the plugin reports an error.
class QRReaderException implements Exception {
  String code;
  String description;

  QRReaderException(this.code, this.description);

  @override
  String toString() => '$runtimeType($code, $description)';
}

// Build the UI texture view of the video data with textureId.
class QRReaderPreview extends StatelessWidget {
  final QRReaderController controller;

  const QRReaderPreview(this.controller);

  @override
  Widget build(BuildContext context) {
    return controller.value.isInitialized ? new Texture(textureId: controller._textureId) : new Container();
  }
}

/// The state of a [QRReaderController].
class QRReaderValue {
  /// True after [QRReaderController.initialize] has completed successfully.
  final bool isInitialized;

  /// True when the camera is scanning.
  final bool isScanning;

  final String errorDescription;

  /// The size of the preview in pixels.
  ///
  /// Is `null` until  [isInitialized] is `true`.
  final Size previewSize;

  const QRReaderValue({
    this.isInitialized,
    this.errorDescription,
    this.previewSize,
    this.isScanning,
  });

  const QRReaderValue.uninitialized()
      : this(
          isInitialized: false,
          isScanning: false,
        );

  /// Convenience getter for `previewSize.height / previewSize.width`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewSize.height / previewSize.width;

  bool get hasError => errorDescription != null;

  QRReaderValue copyWith({
    bool isInitialized,
    bool isScanning,
    String errorDescription,
    Size previewSize,
  }) {
    return new QRReaderValue(
      isInitialized: isInitialized ?? this.isInitialized,
      errorDescription: errorDescription,
      previewSize: previewSize ?? this.previewSize,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class QRReaderController extends ValueNotifier<QRReaderValue> {
  final CameraDescription description;
  final ResolutionPreset resolutionPreset;
  final Function onCodeRead;
  final List<CodeFormat> codeFormats;

  int _textureId;
  bool _isDisposed = false;
  StreamSubscription<dynamic> _eventSubscription;
  Completer<Null> _creatingCompleter;

  QRReaderController(this.description, this.resolutionPreset, this.codeFormats, this.onCodeRead)
      : super(const QRReaderValue.uninitialized());

  /// Initializes the camera on the device.
  ///
  /// Throws a [QRReaderException] if the initialization fails.
  Future<Null> initialize() async {
    if (_isDisposed) {
      return new Future<Null>.value(null);
    }
    try {
      _channel.setMethodCallHandler(_handleMethod);
      _creatingCompleter = new Completer<Null>();
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'initialize',
        <String, dynamic>{
          'cameraName': description.name,
          'resolutionPreset': serializeResolutionPreset(resolutionPreset),
          'codeFormats': serializeCodeFormatsList(codeFormats),
        },
      );
      _textureId = reply['textureId'];
      value = value.copyWith(
        isInitialized: true,
        previewSize: new Size(
          reply['previewWidth'].toDouble(),
          reply['previewHeight'].toDouble(),
        ),
      );
    } on PlatformException catch (e) {
      throw new QRReaderException(e.code, e.message);
    }
    _eventSubscription =
        new EventChannel('io.cloudacy.qr_scan/cameraEvents$_textureId').receiveBroadcastStream().listen(_listener);
    _creatingCompleter.complete(null);
    return _creatingCompleter.future;
  }

  /// Listen to events from the native plugins.
  ///
  /// A "cameraClosing" event is sent when the camera is closed automatically by the system (for example when the app go to background). The plugin will try to reopen the camera automatically but any ongoing recording will end.
  void _listener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    if (_isDisposed) {
      return;
    }

    switch (map['eventType']) {
      case 'error':
        value = value.copyWith(errorDescription: event['errorDescription']);
        break;
      case 'cameraClosing':
        value = value.copyWith(isScanning: false);
        break;
    }
  }

  /// Start a QR scan.
  ///
  /// Throws a [QRReaderException] if the capture fails.
  Future<Null> startScanning() async {
    if (!value.isInitialized || _isDisposed) {
      throw new QRReaderException(
        'Uninitialized QRReaderController',
        'startScanning was called on uninitialized QRReaderController',
      );
    }
    if (value.isScanning) {
      throw new QRReaderException(
        'A scan has already started.',
        'startScanning was called when a recording is already started.',
      );
    }
    try {
      value = value.copyWith(isScanning: true);
      await _channel.invokeMethod(
        'startScanning',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw new QRReaderException(e.code, e.message);
    }
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "updateCode":
        if (value.isScanning) {
          onCodeRead(call.arguments);
          value = value.copyWith(isScanning: false);
        }
    }
  }
}

class CameraDescription {
  final String name;
  final CameraLensDirection lensDirection;

  CameraDescription({this.name, this.lensDirection});

  @override
  bool operator ==(Object o) {
    return o is CameraDescription && o.name == name && o.lensDirection == lensDirection;
  }

  @override
  int get hashCode {
    return hashValues(name, lensDirection);
  }

  @override
  String toString() {
    return '$runtimeType($name, $lensDirection)';
  }
}
*/
