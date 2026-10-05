import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/user_avatar.dart';

/// Bottom sheet to edit the signed-in student's profile: name, target band,
/// exam date and test type. Saves with [Store.updateProfile].
Future<void> showEditProfileSheet(BuildContext context) {
  return showAppSheet<void>(context, const _EditProfileSheet());
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  static const List<double> _bands = <double>[
    5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0,
  ];

  late final TextEditingController _name;
  double? _target;
  DateTime? _exam;

  @override
  void initState() {
    super.initState();
    final acc = Store.I.current;
    _name = TextEditingController(text: acc?.name ?? '');
    _target = acc?.targetBand;
    _exam = acc?.examDate;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _exam != null && !_exam!.isBefore(now)
          ? _exam!
          : now.add(const Duration(days: 60)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _exam = picked);
  }

  Future<void> _changePhoto() async {
    await showAvatarSheet(context);
    if (mounted) setState(() {});
  }

  void _save() {
    final values = <String, dynamic>{'testType': 'Academic'};
    if (_target != null) values['targetBand'] = _target;
    if (_exam != null) values['examDate'] = Store.dateKey(_exam!);
    Store.I.updateProfile(values, name: _name.text);
    context.toast('Profile updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Edit profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          Row(
            spacing: 14,
            children: [
              UserAvatar(size: 56),
              Expanded(
                child: Text(
                  'Profile photo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
              ),
              SoftButton(
                label: 'Change photo',
                leading: AppIcons.camera,
                height: 40,
                fontSize: 13,
                onTap: _changePhoto,
              ),
            ],
          ),
          AppTextField(label: 'Full name', controller: _name),
          Text('Target band', style: TextStyle(fontSize: 13, color: t.textMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in _bands)
                ChipPill(
                  label: b.toStringAsFixed(1),
                  selected: _target == b,
                  onTap: () => setState(() => _target = b),
                ),
            ],
          ),
          Text('Exam date', style: TextStyle(fontSize: 13, color: t.textMuted)),
          AppCard(
            radius: 18,
            color: t.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: _pickDate,
            child: Row(
              spacing: 12,
              children: [
                Icon(AppIcons.calendar, size: 20, color: t.text),
                Expanded(
                  child: Text(
                    _exam == null ? 'Choose your exam date' : Store.weekdayDate(_exam!),
                    style: TextStyle(
                      fontSize: 15,
                      color: _exam == null ? t.textMuted : t.text,
                    ),
                  ),
                ),
                Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 4),
          PrimaryButton(label: 'Save changes', onTap: _save),
        ],
      ),
    );
  }
}

/// Profile photo sheet: choose from gallery, take a photo (phones only),
/// remove. Saves a small base64 JPEG to `profile.photo` (see [UserAvatar]).
Future<void> showAvatarSheet(BuildContext context) {
  return showAppSheet<void>(context, const _AvatarSheet());
}

class _AvatarSheet extends StatefulWidget {
  const _AvatarSheet();

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  bool _busy = false;

  /// The camera source only works on Android / iOS.
  static bool get _canUseCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Store.I.updateProfile(<String, dynamic>{'photo': base64Encode(bytes)});
      context.toast('Profile photo updated');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.toast(
        source == ImageSource.camera
            ? 'Couldn\'t open the camera - check camera permission in Settings'
            : 'Couldn\'t open your photos - check photo permission in Settings',
      );
    }
  }

  void _remove() {
    Store.I.updateProfile(<String, dynamic>{'photo': null});
    context.toast('Profile photo removed');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final acc = context.store.current;
    final photo = acc?.profile['photo'];
    final hasPhoto = photo is String && photo.isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Profile photo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          Center(child: UserAvatar(size: 96)),
          if (_busy)
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.text),
              ),
            ),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListRow(
                  leading: IconCircle(AppIcons.photo, size: 40),
                  title: 'Choose photo',
                  subtitle: 'From your gallery or files',
                  onTap: _busy ? null : () => _pick(ImageSource.gallery),
                ),
                if (_canUseCamera)
                  ListRow(
                    divider: true,
                    leading: IconCircle(AppIcons.camera, size: 40),
                    title: 'Take photo',
                    subtitle: 'Use your camera',
                    onTap: _busy ? null : () => _pick(ImageSource.camera),
                  ),
                if (hasPhoto)
                  ListRow(
                    divider: true,
                    leading: IconCircle(
                      AppIcons.delete,
                      size: 40,
                      bg: t.dangerSoft,
                      fg: t.dangerText,
                    ),
                    title: 'Remove photo',
                    subtitle: 'Show your initials instead',
                    onTap: _busy ? null : _remove,
                  ),
              ],
            ),
          ),
          OutlineButtonX(
            label: 'Cancel',
            height: 50,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
