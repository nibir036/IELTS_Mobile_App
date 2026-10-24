import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
import '../../app/widgets/app_tour.dart';

/// nexted.app · documents.
///
/// Documents attach to a student's applications, so uploading and following
/// them is a student action and belongs in the mobile module. Files go to the
/// shared backend, where the counsellor working the application sees them.
class NextedDocumentsScreen extends StatefulWidget {
  const NextedDocumentsScreen({super.key, this.embedded = false});

  /// Shown as a tab of the study-abroad shell: no back arrow, and the upload
  /// button sits above the bottom nav.
  final bool embedded;

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

  /// Which exam a transcript or certificate is for.
  static const List<(String, String, String)> _levels = <(String, String, String)>[
    ('ssc', 'SSC', 'Secondary School Certificate (or O Levels)'),
    ('hsc', 'HSC', 'Higher Secondary Certificate (or A Levels)'),
    ('bachelors', 'Bachelor’s', 'Undergraduate degree'),
    ('masters', 'Master’s', 'Postgraduate degree'),
  ];

  /// "SSC Transcript", "Bachelor’s Certificate" ...
  static String _levelName(String level, String kind) {
    final l = _levels.where((x) => x.$1 == level).map((x) => x.$2).firstOrNull ?? '';
    final what = kind == 'transcript' ? 'Transcript' : 'Certificate';
    return l.isEmpty ? _labelFor(kind) : '$l $what';
  }

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

    // Transcripts and certificates: which one - SSC, HSC, Bachelor's, Master's.
    var level = '';
    if (kind == 'transcript' || kind == 'certificate') {
      final picked = await showAppSheet<String>(
        context,
        Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const SizedBox(height: 6),
              Text(
                kind == 'transcript' ? 'Which transcript?' : 'Which certificate?',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              for (final l in _levels)
                ListRow(
                  title: _levelName(l.$1, kind),
                  subtitle: l.$3,
                  leading: IconCircle(_iconFor(kind), size: 38, iconSize: 18),
                  trailing: const Icon(AppIcons.chevronRight, size: 20),
                  onTap: () => Navigator.of(ctx).pop(l.$1),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      level = picked;
    }
    final label = level.isEmpty ? _labelFor(kind) : _levelName(level, kind);

    final file = await _pickFile('Add the file');
    if (file == null || !mounted) return;
    final (bytes, ext) = file;

    setState(() => _busy = true);
    try {
      await NextedApi.upload(
        NextedConfig.documentUpload,
        bytes: bytes,
        kind: kind,
        ext: ext,
        name: label,
        level: level,
        contentType: _contentType(ext),
      );
      if (!mounted) return;
      context.toast('$label uploaded');
      await _load();
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Camera or a file (PDF, JPG, PNG up to 10 MB): (bytes, extension), or
  /// null when cancelled or refused (the student is told why).
  Future<(Uint8List, String)?> _pickFile(String title) async {
    // Camera, or a file already on the phone: PDF, JPG or PNG.
    final source = await showAppSheet<String>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            ListRow(
              title: 'Take a photo',
              subtitle: 'Photograph the document',
              leading: IconCircle(AppIcons.camera, size: 38, iconSize: 18),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListRow(
              title: 'Choose a file',
              subtitle: 'PDF, JPG or PNG - up to 10 MB',
              leading: IconCircle(AppIcons.attach, size: 38, iconSize: 18),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return null;

    // (bytes, extension) of the chosen file.
    Uint8List? bytes;
    var ext = 'jpg';
    try {
      if (source == 'camera') {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
        if (photo == null) return null;
        bytes = await photo.readAsBytes();
        ext = _extOf(photo.name) ?? 'jpg';
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _allowedExts.toList(),
          withData: true,
        );
        final f = picked?.files.firstOrNull;
        if (f == null) return null;
        bytes = f.bytes;
        ext = (f.extension ?? _extOf(f.name) ?? '').toLowerCase();
      }
    } catch (_) {
      if (mounted) context.toast('Couldn’t open the picker. Check the app’s permissions.');
      return null;
    }
    if (!mounted) return null;
    if (bytes == null || bytes.isEmpty) {
      context.toast('Couldn’t read that file. Try another one.');
      return null;
    }
    if (!_allowedExts.contains(ext)) {
      context.toast('Upload a PDF, JPG or PNG file.');
      return null;
    }
    if (bytes.length > _maxBytes) {
      context.toast('That file is larger than 10 MB. Try a smaller scan or a photo.');
      return null;
    }
    return (bytes, ext == 'jpeg' ? 'jpg' : ext);

  }

  static String _contentType(String ext) =>
      ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');

  /// Swap a document's file for a new one. It keeps its type and name, and
  /// goes back to Pending for the counsellor to check again.
  Future<void> _replace(Map<String, dynamic> doc) async {
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to replace documents.');
      return;
    }
    final name = doc.s('name').isEmpty ? 'this document' : doc.s('name');
    final file = await _pickFile('Replace $name');
    if (file == null || !mounted) return;
    final (bytes, ext) = file;
    setState(() => _busy = true);
    try {
      await NextedApi.upload(
        '${NextedConfig.documents}/${doc.s('id')}/file',
        bytes: bytes,
        kind: doc.s('kind'),
        ext: ext,
        contentType: _contentType(ext),
      );
      if (!mounted) return;
      context.toast('$name replaced');
      await _load();
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Documents: PDF, JPEG and PNG, up to 10 MB (the server checks too).
  static const Set<String> _allowedExts = <String>{'pdf', 'jpg', 'jpeg', 'png'};
  static const int _maxBytes = 10 * 1024 * 1024;

  static String? _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toLowerCase() : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return AppScreen(
      gap: 13,
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 12, 20, 24),
      // In the study-abroad shell the button sits above the bottom nav.
      footerPadding: EdgeInsets.fromLTRB(20, 8, 20, widget.embedded ? 104 : 16),
      footer: TourTarget(
        id: 'documents.upload',
        child: PrimaryButton(
          label: _busy ? 'Uploading…' : 'Upload a document',
          leading: AppIcons.cloudUpload,
          enabled: !_busy,
          onTap: _addDocument,
        ),
      ),
      children: [
        TopBar(
          title: 'Documents',
          subtitle: 'Upload once, your counsellor sees it',
          showBack: !widget.embedded,
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
            message: 'Add your passport, transcripts and certificates here - PDF, JPG or PNG, '
                'up to 10 MB each. They stay with your file, so you never have to send them twice.',
            icon: AppIcons.doc,
          )
        else ...[
          SectionTitle('${_docs.length} uploaded', fontSize: 15),
          for (final d in _docs)
            _DocumentCard(doc: d, icon: _iconFor(d.s('kind')), onReplace: _busy ? null : () => _replace(d)),
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
  const _DocumentCard({required this.doc, required this.icon, this.onReplace});

  final Map<String, dynamic> doc;
  final IconData icon;

  /// Upload a new file in place of this one (null while another upload runs).
  final VoidCallback? onReplace;

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
                const SizedBox(height: 6),
                SoftButton(
                  label: 'Replace file',
                  leading: AppIcons.cloudUpload,
                  height: 34,
                  fontSize: 13,
                  onTap: onReplace,
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
