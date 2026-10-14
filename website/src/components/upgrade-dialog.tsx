'use client';

import { Icon, PrimaryButton, SoftButton } from './ui';
import s from './dialog.module.css';
import { Portal } from '@/components/portal';

const TITLES: Record<string, string> = {
  writing_task1: 'Your free Writing Task 1 is used',
  writing_task2: 'Your free Writing Task 2 is used',
  writing_test: 'Your free Writing Test is used',
  speaking_part1: 'Your free Speaking Part 1 is used',
  speaking_part2: 'Your free Speaking Part 2 is used',
  speaking_part3: 'Your free Speaking Part 3 is used',
  speaking_test: 'Your free Speaking Test is used',
  mock: 'Your free Full Mock Test is used',
  diagnostic: 'Your free level test is used',
  pronunciation: 'Your 5 free pronunciation checks are used',
  rewrite: 'Your free Band 8 rewrite is used',
  quick_check: 'The quick check is part of Pro',
  plan: 'Your 3-day free plan is over',
};

const PERKS = [
  'Unlimited AI feedback on writing and speaking',
  'Unlimited full mock tests with band reports',
  'A study plan that adapts every week, with the quick check',
  'Unlimited pronunciation checks and Band 8 rewrites',
];

/** The app's upgrade sheet (lib/features/home/upgrade_sheet.dart), shown on HTTP 402. */
export function UpgradeDialog({ feature, onClose }: { feature: string; onClose: () => void }) {
  return (
    <Portal><div className={s.backdrop} role="dialog" aria-modal="true" aria-labelledby="upgrade-title" onClick={onClose}>
      <div className={s.sheet} onClick={(e) => e.stopPropagation()}>
        <h2 id="upgrade-title" className={s.title}>
          {TITLES[feature] ?? 'This is part of Pro'}
        </h2>
        <p className={s.body}>The free plan gives you one of each test with AI feedback. Upgrade to Pro to keep practising.</p>
        <ul className={s.perks}>
          {PERKS.map((p) => (
            <li key={p}>
              <Icon name="check_circle" size={18} color="var(--success)" />
              <span>{p}</span>
            </li>
          ))}
        </ul>
        <div className={s.actions}>
          <PrimaryButton href="/app/upgrade" block>
            See Pro plans
          </PrimaryButton>
          <SoftButton onClick={onClose}>Not now</SoftButton>
        </div>
      </div>
    </div></Portal>
  );
}

/** A simple confirm dialog in the app's style. */
export function ConfirmDialog({
  title,
  message,
  confirm,
  cancel,
  onConfirm,
  onCancel,
}: {
  title: string;
  message: string;
  confirm: string;
  cancel: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Portal><div className={s.backdrop} role="dialog" aria-modal="true" onClick={onCancel}>
      <div className={s.sheet} onClick={(e) => e.stopPropagation()}>
        <h2 className={s.title}>{title}</h2>
        <p className={s.body}>{message}</p>
        <div className={s.actions}>
          <PrimaryButton block onClick={onConfirm}>
            {confirm}
          </PrimaryButton>
          <SoftButton onClick={onCancel}>{cancel}</SoftButton>
        </div>
      </div>
    </div></Portal>
  );
}
