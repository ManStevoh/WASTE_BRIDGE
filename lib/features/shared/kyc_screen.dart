import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/kyc_submission.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  static const _docTypes = <String>[
    'national_id',
    'passport',
    'drivers_license',
    'business_registration',
    'other',
  ];

  String _documentType = _docTypes.first;
  PlatformFile? _picked;
  bool _submitting = false;
  bool _loadingList = true;
  List<KycSubmission> _history = [];
  String? _listError;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final items = await ref.read(kycServiceProvider).listSubmissions();
      if (mounted) {
        setState(() {
          _history = items;
          _loadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listError = userVisibleError(e, fallback: 'Could not load submissions.');
          _loadingList = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _picked = result.files.first);
    }
  }

  Future<void> _submit() async {
    final file = _picked;
    if (file == null || file.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a document (JPG, PNG, or PDF).')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(kycServiceProvider).submit(
            documentType: _documentType,
            filePath: file.path!,
            filename: file.name,
          );
      await ref.read(authNotifierProvider.notifier).refreshFromServer();
      ref.invalidate(kycSubmissionsProvider);
      if (!mounted) return;
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document submitted for review.')),
      );
      await _refreshList();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Upload failed.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userVisibleError(e, fallback: 'Upload failed.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Identity verification')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          if (auth != null)
            AppSectionCard(
              title: 'Your status',
              child: Text(
                'KYC: ${auth.kycStatus.name}',
                style: theme.textTheme.titleMedium,
              ),
            ),
          SizedBox(height: AppSpacing.sm),
          AppSectionCard(
            title: 'Submit a document',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _documentType,
                  decoration: const InputDecoration(
                    labelText: 'Document type',
                    border: OutlineInputBorder(),
                  ),
                  items: _docTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _documentType = v);
                        },
                ),
                SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _picked == null
                        ? 'Choose file (max 10 MB)'
                        : _picked!.name,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit for review'),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Submission history',
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _listError != null
                    ? Text(_listError!, style: TextStyle(color: theme.colorScheme.error))
                    : _history.isEmpty
                        ? Text(
                            'No submissions yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Column(
                            children: _history
                                .map(
                                  (s) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(s.documentType.replaceAll('_', ' ')),
                                    subtitle: Text(
                                      '${s.status}'
                                      '${s.createdAt != null ? ' · ${s.createdAt!.toLocal()}' : ''}',
                                    ),
                                    trailing: s.status == 'rejected' &&
                                            s.rejectionReason != null
                                        ? IconButton(
                                            icon: const Icon(Icons.info_outline),
                                            onPressed: () {
                                              showDialog<void>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Reason'),
                                                  content: Text(s.rejectionReason!),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
          ),
        ],
      ),
    );
  }
}
