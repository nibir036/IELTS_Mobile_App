import { getPack } from './packs';

export type Raw = Record<string, unknown>;

export interface ResourcesBank {
  vocab: Raw[];
  idioms: Raw[];
  phrasalVerbs: Raw[];
  irregularVerbs: Raw[];
  connectors: Raw[];
  academicWords: Raw[];
  topics: Raw[];
}

export async function resourcesBank(): Promise<ResourcesBank> {
  const b = await getPack<Raw>('bank.resources');
  const l = (k: string) => (Array.isArray(b[k]) ? (b[k] as Raw[]) : []);
  return {
    vocab: l('vocab'),
    idioms: l('idioms'),
    phrasalVerbs: l('phrasalVerbs'),
    irregularVerbs: l('irregularVerbs'),
    connectors: l('connectors'),
    academicWords: l('academicWords'),
    topics: l('topics'),
  };
}
