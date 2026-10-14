// Notification groups the student can switch on and off (NotifGroup in
// lib/app/services/notification_service.dart). Saved in kv `notif.groups`.

export const NOTIF_GROUPS: Array<{ id: string; label: string; description: string; icon: string }> = [
  { id: 'study', label: 'Study reminders', description: 'Daily reminder, streak alerts and a weekly recap', icon: 'school' },
  { id: 'exam', label: 'Exam & schedule', description: 'Exam countdown, mock test days and planned sessions', icon: 'calendar_month' },
  { id: 'results', label: 'Results', description: 'When your writing or speaking has been scored', icon: 'bar_chart' },
  { id: 'achievements', label: 'Achievements', description: 'New milestones and finished course stages', icon: 'workspace_premium' },
  { id: 'news', label: 'News & account', description: 'New content, plan updates and AI scoring limits', icon: 'auto_awesome' },
];
