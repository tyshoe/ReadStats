import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/app_snackbar.dart';

/// Full-screen camera capture for a book cover. Mirrors the barcode scanner's
/// controls: defaults to the back camera and offers camera swapping and a flash
/// toggle. Pops with the captured image [File], or null if cancelled.
class CoverCameraPage extends StatefulWidget {
  const CoverCameraPage({super.key});

  @override
  State<CoverCameraPage> createState() => _CoverCameraPageState();
}

class _CoverCameraPageState extends State<CoverCameraPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeController(_controller));
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      // Release the camera while backgrounded and clear the reference so we
      // don't dispose the same (already-released) controller a second time.
      unawaited(_disposeController(controller));
      setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _startController(_cameraIndex);
    }
  }

  /// Dispose [controller], swallowing the errors camera_android_camerax can
  /// throw from releaseSurfaceProvider during teardown.
  Future<void> _disposeController(CameraController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {
      // Best-effort release; nothing actionable on failure.
    }
  }

  Future<void> _initCameras() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          AppSnackbar.show('No camera available');
          Navigator.of(context).pop();
        }
        return;
      }
      _cameras = cameras;
      // Default to the back camera, falling back to the first available.
      final backIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _startController(backIndex >= 0 ? backIndex : 0);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show('Could not start the camera');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _startController(int index) async {
    // Release the current camera first: on Android (camerax) a single hardware
    // camera can't be held by two controllers at once, so initializing the new
    // one while the old is still open throws and the switch silently fails.
    final previous = _controller;
    if (previous != null) {
      setState(() => _controller = null);
      await _disposeController(previous);
    }
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
    } catch (_) {
      if (mounted) AppSnackbar.show('Could not start the camera');
      return;
    }
    if (!mounted) {
      await _disposeController(controller);
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = index;
    });
  }

  bool get _hasMultipleCameras => _cameras.length > 1;

  Future<void> _switchCamera() async {
    if (!_hasMultipleCameras) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _startController(next);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flashMode) + 1) % order.length];
    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      if (mounted) AppSnackbar.show('Flash not available on this camera');
    }
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      default:
        return Icons.flash_on;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }
    setState(() => _isTakingPicture = true);
    try {
      final shot = await controller.takePicture();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(File(shot.path));
    } catch (_) {
      if (mounted) AppSnackbar.show('Could not capture the photo');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take a photo'),
        actions: [
          if (_hasMultipleCameras)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Switch camera',
              onPressed: _switchCamera,
            ),
          IconButton(
            icon: Icon(_flashIcon),
            tooltip: 'Flash',
            onPressed: ready ? _cycleFlash : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ready
                ? Center(child: CameraPreview(controller))
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: GestureDetector(
                onTap: ready ? _capture : null,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white38, width: 4),
                  ),
                  child: _isTakingPicture
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
