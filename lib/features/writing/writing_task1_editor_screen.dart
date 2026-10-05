import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'editor_common.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C2 · Writing Task 1 Prompt & Editor (separate practice page for Task 1).
///
/// Args: `{'promptId'?, 'text'?}`. Restores the saved draft for the prompt,
/// autosaves to kv `writing.draft.task1`, submits → C12 → C5.
class WritingTask1EditorScreen extends StatefulWidget {
  const WritingTask1EditorScreen({super.key});

  @override
  State<WritingTask1EditorScreen> createState() =>
      _WritingTask1EditorScreenState();
}

class _WritingTask1EditorScreenState extends State<WritingTask1EditorScreen>
    with WritingEditorLogic<WritingTask1EditorScreen> {
  @override
  int get editorTask => 1;

  @override
  TextEditingController createController(String text) =>
      _HighlightController(text: text);

  @override
  void dispose() {
    disposeEditor();
    super.dispose();
  }

  String _hint(int words) {
    final hints = WritingContent.all.m('task1').m('aiHints');
    if (words == 0) return hints.s('empty');
    final hasOverview =
        RegExp(r'\boverall\b', caseSensitive: false).hasMatch(controller.text);
    if (!hasOverview) return hints.s('noOverview');
    if (words < minWords) return hints.s('overview');
    return hints.s('long');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final chart = prompt.m('chart');
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
              icon: AppIcons.back,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: pickPrompt,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prompt.s('header'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    prompt.s('subheader'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
              ),
            ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(AppIcons.clock, size: 16, color: t.text),
                  Text(
                    mmss(secondsLeft),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!keyboardOpen)
          AppCard(
            radius: 24,
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Text(
                      prompt.s('prompt'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: t.isNight ? t.text : t.textSoft,
                      ),
                    ),
                    if (chart.isNotEmpty || prompt.s('image').isNotEmpty)
                      WritingVisual(prompt: prompt, height: 120),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your response',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: wc(t, 0xFFE9EFFF, 0xFF1C2030),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$words / $minWords words',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor: t.alert,
                    cursorWidth: 1.5,
                    style: TextStyle(fontSize: 15, height: 1.6, color: t.text),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Start writing your report…',
                      hintStyle: TextStyle(color: t.textFaint, fontSize: 15),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(AppIcons.sparkle, size: 14, color: t.iconAccent),
                      Expanded(
                        child: Text(
                          _hint(words),
                          style: TextStyle(
                            fontSize: 12,
                            color: t.isNight ? t.text : t.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              flex: 1,
              child: WFlatButton(
                label: 'Save draft',
                bg: t.surface,
                fg: t.text,
                onTap: () {
                  saveDraft();
                  context.toast('Draft saved');
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Submit for AI review',
                height: 56,
                radius: 18,
                fontSize: 15,
                onTap: submitEssay,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Text controller that paints a pink highlight behind the overview
/// ("Overall, …" up to the next comma or full stop) - the AI's
/// "overview found" marker in the Task 1 artboard.
class _HighlightController extends TextEditingController {
  _HighlightController({super.text});

  static final RegExp _overview = RegExp(r'Overall,[^.,\n]*');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final m = _overview.firstMatch(text);
    if (m == null || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final idx = m.start;
    final end = m.end;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, idx)),
        TextSpan(
          text: text.substring(idx, end),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFE2D8),
            color: Color(0xFF151515),
          ),
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }
}
