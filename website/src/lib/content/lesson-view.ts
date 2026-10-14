// A lesson resolved on the server into the student's explanation language,
// ready for the lesson player (components/lesson-player.tsx).

export type StepView =
  | {
      type: 'choice';
      title: string;
      prompt: string;
      passage: string;
      options: Array<{ text: string; sub: string }>;
      answer: number;
      right: string;
      explain: string;
      bars: Array<{ label: string; value: number; text: string }>;
    }
  | { type: 'roadmap'; title: string; items: string[]; note: string }
  | { type: 'concepts'; title: string; intro: string; cards: Array<{ icon: string; title: string; body: string }> }
  | {
      type: 'contrast';
      title: string;
      intro: string;
      weak: { label: string; text: string; mark: string };
      strong: { label: string; text: string; mark: string };
      tip: string;
    }
  | { type: 'read'; title: string; blocks: unknown[][] }
  | {
      type: 'practice';
      title: string;
      task: string;
      prompt: string;
      items: Array<{ text: string; minutes: number; href: string; action: string }>;
      plan: string[];
      tip: string;
    }
  | {
      type: 'sampleFeedback';
      title: string;
      intro: string;
      band: number;
      criteria: Array<{ name: string; band: number }>;
      good: string[];
      improve: string[];
    }
  | { type: 'unknown' };

export interface LessonNext {
  id: string;
  title: string;
  stageIndex: number;
  lessonIndex: number;
  stageLessons: number;
  minutes: number;
  sameStage: boolean;
}

export interface LessonView {
  id: string;
  module: string;
  moduleName: string;
  stageId: string;
  stageIndex: number;
  lessonIndex: number;
  stageLessons: number;
  /** Other lessons of this stage (to tell when the stage is finished). */
  stageLessonIds: string[];
  title: string;
  english: string;
  intro: string;
  greeting: string;
  minutes: number;
  xp: number;
  learned: string[];
  steps: StepView[];
  next: LessonNext | null;
  lang: string;
  langs: string[];
  rtl: boolean;
  firstName: string;
}
