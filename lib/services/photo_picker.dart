import 'package:image_picker/image_picker.dart';

/// Opens the photo library and returns the chosen file's path, or null.
Future<String?> pickPhotoPath() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // Downscale on the phone: the server accepts up to 10 MB, but a 1600 px
    // photo is plenty for an avatar or a post.
    maxWidth: 1600,
    imageQuality: 85,
  );
  return file?.path;
}

/// Opens the video library and returns the chosen file's path, or null. The
/// server accepts at most 60 seconds and 50 MB.
Future<String?> pickVideoPath() async {
  final file = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(seconds: 60),
  );
  return file?.path;
}
