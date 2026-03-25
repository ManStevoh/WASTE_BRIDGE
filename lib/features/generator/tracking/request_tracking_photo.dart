import 'package:image_picker/image_picker.dart';

Future<String?> pickProofImagePath() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  return picked?.path;
}
