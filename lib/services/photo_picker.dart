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
