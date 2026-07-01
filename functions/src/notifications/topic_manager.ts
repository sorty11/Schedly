import { sanitizeTopic } from '../utils';

export function getTargetTopic(division: string, batch?: string, role?: string): string {
  if (role && role !== 'student') {
    return `${role}_${sanitizeTopic(division)}`;
  }
  
  if (batch) {
    return `batch_${sanitizeTopic(batch)}_${sanitizeTopic(division)}`;
  }
  
  return `division_${sanitizeTopic(division)}`;
}
