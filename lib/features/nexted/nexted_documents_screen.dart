import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// nexted.app · documents.
///
/// Documents attach to a student's applications, so uploading and following
/// them is a student action and belongs in the mobile module. Files go to the
/// shared backend, where the counsellor working the application sees them.
class NextedDocumentsScreen extends StatefulWidget {
  const NextedDocumentsScreen({super.key});

  @override
  State<NextedDocumentsScreen> createState() => _NextedDocumentsScreenState();
}

class _NextedDocumentsScreenState extends State<NextedDocumentsScreen> {
  /// The document types NextED asks for, in the order they are usually needed.
  static const List<(String, String, IconData)> _kinds = <(String, String, IconData)>[
    ('passport', 'Passport', AppIcons.doc),
    ('transcript', 'Academic transcript', AppIcons.school),
    ('certificate', 'Certificate', AppIcons.medal),
    ('ielts', 'IELTS result', AppIcons.chart),
    ('photo', 'Passport photo', AppIcons.camera),
    ('other', 'Other document', AppIcons.attach),
  ];

  List<Map<String, dynamic>> _docs = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!NextedApi.ready) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await NextedApi.get(NextedConfig.documents);
      final list = r.l('documents').isNotEmpty ? r.l('documents') : r.l('items');
      if (!mounted) return;
      setState(() {
        _docs = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  static String _labelFor(String kind) {
    for (final k in _kinds) {
      if (k.$1 == kind) return k.$2;
    }
    return kind.isEmpty ? 'Document' : kind;
  }

  static IconData _iconFor(String kind) {
    for (final k in _kinds) {
      if (k.$1 == kind) return k.$3;
    }
    return AppIcons.doc;
  }

  /// Pick the type, then the file, then upload it.
  Future<void> _addDocument() async {
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to upload documents.');
      return;
    }
    final kind = await showAppSheet<String>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const SizedBox(height: 6),
            const Text(
              'What are you uploading?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            for (final k in _kinds)
              ListRow(
                title: k.$2,
                leading: IconCircle(k.$3, size: 38, iconSize: 18),
                trailing: const Icon(AppIcons.chevronRight, size: 20),
                onTap: () => Navigator.of(ctx).pop(k.$1),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    final source = await showAppSheet<ImageSource>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Add the file',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            ListRow(
              title: 'Take a photo',
              subtitle: 'Photograph the document',
              leading: IconCircle(AppIcons.camera, size: 38, iconSize: 18),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListRow(
              title: 'Choose from gallery',
              subtitle: 'A photo or scan already on your phone',
              leading: IconCircle(AppIcons.photo, size: 38, iconSize: 18),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, imageQuality: 88);
    } catch (_) {
      if (mounted) context.toast('Couldn’t open the picker. Check the app’s permissions.');
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final ext = dot > 0 && dot < file.name.length - 1
          ? file.name.substring(dot + 1).toLowerCase()
          : 'jpg';
      await NextedApi.upload(
        NextedConfig.documentUpload,
        bytes: bytes,
        kind: kind,
        ext: ext,
        name: _labelFor(kind),
        contentType: file.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      context.toast('${_labelFor(kind)} uploaded');
      await _load();
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return AppScreen(
      gap: 13,
      footer: PrimaryButton(
        label: _busy ? 'Uploading…' : 'Upload a document',
        leading: AppIcons.cloudUpload,
        enabled: !_busy,
        onTap: _addDocument,
      ),
      children: [
        TopBar(
          title: 'Documents',
          subtitle: 'Upload once, your counsellor sees it',
          onBack: () => context.back(),
        ),

        if (!NextedConfig.hasApi)
          const NextedOfflineNotice(
            message: 'Not connected to the study-abroad server yet, so uploads are off. '
                'Build with --dart-define=NEXTED_API_BASE_URL=… to send documents.',
          ),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t load your documents',
            message: _error,
            icon: AppIcons.cloudOff,
            actionLabel: 'Try again',
            onAction: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _load();
            },
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_docs.isEmpty)
          const EmptyState(
            title: 'No documents yet',
            message: 'Add your passport, transcripts and certificates here. '
                'They stay with your file, so you never have to send them twice.',
            icon: AppIcons.doc,
          )
        else ...[
          SectionTitle('${_docs.length} uploaded', fontSize: 15),
          for (final d in _docs) _DocumentCard(doc: d, icon: _iconFor(d.s('kind'))),
        ],

        Text(
          'Clear photographs of the whole page work best. Your counsellor will ask '
          'again if anything is hard to read.',
          style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
        ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.icon});

  final Map<String, dynamic> doc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final uploaded = DateTime.tryParse(doc.s('uploadedAt').isEmpty ? doc.s('createdAt') : doc.s('uploadedAt'))?.toLocal();
    final note = doc.s('note');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          IconCircle(icon, size: 42, iconSize: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  doc.s('name').isEmpty ? 'Document' : doc.s('name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  uploaded == null ? 'Uploaded' : 'Uploaded ${Store.timeAgo(uploaded)}',
                  style: TextStyle(fontSize: 12.5, color: t.textMuted),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: t.textSoft),
                  ),
              ],
            ),
          ),
          NextedStatusTag(doc.s('status')),
        ],
      ),
    );
  }
}
