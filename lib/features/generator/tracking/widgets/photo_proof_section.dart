import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';

class PhotoProofSection extends StatelessWidget {
  const PhotoProofSection({
    super.key,
    required this.hasBeforePhoto,
    required this.hasAfterPhoto,
    required this.onUploadBefore,
    required this.onUploadAfter,
  });

  final bool hasBeforePhoto;
  final bool hasAfterPhoto;
  final VoidCallback onUploadBefore;
  final VoidCallback onUploadAfter;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Photo Proof',
      child: Column(
        children: [
          InfoRow(
            label: 'Before Pickup',
            value: hasBeforePhoto ? 'Uploaded' : 'Not uploaded',
          ),
          InfoRow(
            label: 'After Pickup',
            value: hasAfterPhoto ? 'Uploaded' : 'Not uploaded',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: hasBeforePhoto ? null : onUploadBefore,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Before'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasAfterPhoto ? null : onUploadAfter,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload After'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
