import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/api_client.dart';
import '../../app/services/config.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Settings → Your devices: the account works on up to 2 devices, one
/// signed-in screen at a time. A further device is locked for 48 hours; a
/// device can be removed once every 30 days (server/src/lib/devices.ts).
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppConfig.hasApi) {
      setState(() => _error = 'Devices are managed by the nextED server. This build runs offline.');
      return;
    }
    try {
      final r = await ApiClient.get('/v1/me/devices');
      if (!mounted) return;
      setState(() {
        _data = r;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _remove(Map<String, dynamic> d) async {
    final days = _data?.i('removeCooldownDays') ?? 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this device?'),
        content: Text(
          '“${d.s('name')}” will be signed out and its place freed for another device. '
          'You can remove a device once every $days days.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ApiClient.request('DELETE', '/v1/me/devices/${d.s('id')}');
      if (!mounted) return;
      setState(() => _data = r);
      context.toast('Device removed');
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static IconData _iconFor(String platform) => switch (platform) {
        'Web' || 'Windows' || 'macOS' || 'Linux' => AppIcons.devices,
        _ => AppIcons.smartphone,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final data = _data;
    final devices = data?.l('devices') ?? const <Map<String, dynamic>>[];
    final max = data?.i('maxDevices') ?? 2;
    final lockHours = data?.i('lockHours') ?? 48;
    final next = DateTime.tryParse(data?.s('nextRemovalAt') ?? '');
    final active = devices.where((d) => d.s('status') == 'active').length;

    return AppScreen(
      gap: 14,
      children: [
        TopBar(title: 'Your devices', subtitle: 'Up to $max devices · one screen at a time', onBack: () => context.back()),
        AppCard(
          radius: 22,
          color: t.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              const Text('How it works', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              for (final line in <String>[
                'Your account works on up to $max devices.',
                'Only one can be signed in at a time: signing in on one signs the other out.',
                'Signing in on a further device locks that device for $lockHours hours.',
                'You can remove a device once every ${data?.i('removeCooldownDays') ?? 30} days.',
              ])
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(width: 5, height: 5, decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle)),
                    ),
                    Expanded(child: Text(line, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textSoft))),
                  ],
                ),
            ],
          ),
        ),
        if (_error != null)
          EmptyState(title: 'Couldn’t load your devices', message: _error, icon: AppIcons.devices, actionLabel: 'Try again', onAction: () {
            setState(() => _error = null);
            _load();
          })
        else if (data == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          SectionTitle('$active of $max in use', fontSize: 15),
          for (final d in devices) _DeviceCard(device: d, icon: _iconFor(d.s('platform')), busy: _busy, onRemove: () => _remove(d)),
          if (next != null)
            Text(
              'You can remove another device from ${Store.weekdayDate(next.toLocal())}.',
              style: TextStyle(fontSize: 12.5, color: t.textMuted),
            ),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.icon, required this.busy, required this.onRemove});

  final Map<String, dynamic> device;
  final IconData icon;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final locked = device.s('status') == 'locked';
    final current = device.b('current');
    final until = DateTime.tryParse(device.s('lockedUntil'))?.toLocal();
    final last = DateTime.tryParse(device.s('lastSeenAt'))?.toLocal();
    final sub = locked
        ? 'Tried to sign in · locked until ${until == null ? '-' : '${Store.weekdayDate(until)}, ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}'}'
        : current
            ? 'You’re using this device'
            : 'Last active ${last == null ? '-' : Store.timeAgo(last)}';
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: locked ? t.accentSoft : t.surfaceAlt2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(locked ? AppIcons.lock : icon, size: 20, color: t.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  device.s('name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
              ],
            ),
          ),
          if (current)
            const Tag('This device', tone: TagTone.primary, height: 24)
          else if (!locked)
            SoftButton(label: 'Remove', height: 36, onTap: busy ? null : onRemove),
        ],
      ),
    );
  }
}
