import * as admin from 'firebase-admin';

admin.initializeApp();

export { verifyCRRole, verifySRRole, verifyFacultyRole } from './roles';
export { createSection } from './sections';
export { removeStudent, restoreStudent } from './memberships';
export { removeFaculty } from './faculty';
