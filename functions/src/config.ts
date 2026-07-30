import { defineSecret } from 'firebase-functions/params';

export const MASTER_PASSWORD = defineSecret('MASTER_PASSWORD');
export const FACULTY_MASTER_PASSWORD = defineSecret('FACULTY_MASTER_PASSWORD');
