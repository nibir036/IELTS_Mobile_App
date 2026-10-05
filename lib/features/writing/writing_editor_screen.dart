import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'editor_common.dart';
import 'widgets.dart';

/// C3 · Task Prompt & Editor (Task 2 practice page).
///
/// Args: `{'promptId'?, 'text'?}`. Restores the saved draft for the prompt,
/// autosaves to kv `writing.draft.task2`, submits → C12 → C5.
class WritingEditorScreen extends StatefulWidget {
  const WritingEditorScreen({super.key});

  @override
  State<WritingEditorScreen> createState() => _WritingEditorScreenState();
}

class _WritingEditorScreenState extends State<WritingEditorScreen>
    with WritingEditorLogic<WritingEditorScreen> {
  final UndoHistoryController _undo = UndoHistoryController();
  bool _promptOpen = true;
  bool _focusMode = false;

  @override
  int get editorTask => 2;

  @override
  TextEditingController createController(String text) =>
      TextEditingController(text: text);

  @override
  void dispose() {
    disposeEditor();
    _undo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showPrompt = !_focusMode && !keyboardOpen;

    final secondsLeft = this.secondsLeft;
    final words = this.words;

    return AppScreen(
      scroll: false,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gap: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            IconBox(
              icon: AppIcons.close,
              tooltip: 'Exit editor',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Icon(
                          AppIcons.timer,
                          size: 18,
                          color: secondsLeft < 300 ? t.warning : t.text,
                        ),
                        Text(
                          mmss(secondsLeft),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: secondsLeft < 300 ? t.warning : t.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PrimaryButton(
              label: 'Submit',
              expand: false,
              height: 44,
              radius: 16,
              fontSize: 15,
              onTap: submitEssay,
            ),
          ],
        ),
        if (showPrompt)
          HeroCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: pickPrompt,
                          child: WPill(
                            prompt.s('typeLabel'),
                            bg: t.heroChip,
                            fg: t.heroText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _promptOpen = !_promptOpen),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          _promptOpen
                              ? AppIcons.chevronUp
                              : AppIcons.chevronDown,
                          size: 20,
                          color: t.heroText,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_promptOpen) ...[
                  Text(
                    prompt.s('prompt'),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: t.heroText,
                    ),
                  ),
                  Text(
                    prompt.s('requirement'),
                    style: TextStyle(
                      fontSize: 12,
                      color: t.heroMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: TextField(
              controller: controller,
              undoController: _undo,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: t.text,
              cursorWidth: 2,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: t.isNight ? t.text : const Color(0xFF2A2629),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Start writing your essay…',
                hintStyle: TextStyle(color: t.textFaint, fontSize: 16),
              ),
            ),
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    RingProgress(
                      value: minWords <= 0 ? 0 : words / minWords,
                      size: 36,
                      stroke: 4,
                      track: wc(t, 0xFFF6E8E4, 0xFF23273A),
                      fill: t.alert,
                    ),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$words',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' / $minWords words',
                              style: TextStyle(color: t.textMuted),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: t.text),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      saved ? AppIcons.check : AppIcons.sync,
                      size: 14,
                      color: t.textMuted,
                    ),
                    Text(
                      saved ? 'Saved' : 'Saving…',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            IconBox(
              icon: AppIcons.replay,
              circle: true,
              size: 52,
              bg: t.surface,
              tooltip: 'Undo',
              onTap: () => _undo.undo(),
            ),
            IconBox(
              icon: _focusMode ? AppIcons.close : AppIcons.target,
              circle: true,
              size: 52,
              bg: t.primary,
              fg: t.onPrimary,
              tooltip: 'Focus mode',
              onTap: () => setState(() => _focusMode = !_focusMode),
            ),
          ],
        ),
      ],
    );
  }
}
