import re

def main():
    with open('lib/dashboard_page.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    target = """                                  if (entry.batch != 'Whole Class' || (entry.room != null && entry.room!.isNotEmpty))
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.xs - 2),
                                      child: Text(
                                        [
                                          if (entry.batch != 'Whole Class') entry.batch,
                                          if (entry.room != null && entry.room!.isNotEmpty) 'Room ${entry.room}',
                                        ].join(' · '),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                    ),"""

    replacement = """                                  if (entry.batch != 'Whole Class' || (entry.room != null && entry.room!.isNotEmpty))
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.xs - 2),
                                      child: Text(
                                        [
                                          if (entry.batch != 'Whole Class') entry.batch,
                                          if (entry.room != null && entry.room!.isNotEmpty) 'Room ${entry.room}',
                                        ].join(' · '),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: sem.onSurfaceMuted,
                                        ),
                                      ),
                                    ),
                                  Builder(builder: (context) {
                                    if (attendanceRecords == null) return const SizedBox.shrink();
                                    
                                    String subj = entry.subject;
                                    String comp = entry.component;
                                    if (subj.toUpperCase().contains('DATA STRUCTURES') || subj == 'DSA') {
                                      subj = 'DSA';
                                      if (comp.toUpperCase().contains('LAB') || comp.toUpperCase().contains('PRACTICAL')) comp = 'Lab';
                                      else comp = 'Theory';
                                    }
                                    
                                    final merged = ['DM', 'Discrete Mathematics', 'PnS', 'SnS', 'Python', 'PROGRAMMING WITH PYTHON', 'Signals and Systems', 'Principles of Economics and Managemen'];
                                    String key = merged.contains(subj) ? '${subj}_Merged' : '${subj}_$comp';
                                    
                                    final record = attendanceRecords![key];
                                    if (record == null) return const SizedBox.shrink();
                                    
                                    int p = record.present;
                                    int a = record.absent;
                                    double attendPct = (p + 1) / (p + a + 1) * 100;
                                    double skipPct = p / (p + a + 1) * 100;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? sem.surfaceElevated1 : sem.borderSubtle.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '🟢 If attend: ${attendPct.toStringAsFixed(1)}%  |  🔴 If skip: ${skipPct.toStringAsFixed(1)}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : sem.onSurfaceMuted,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),"""
    
    if target in content:
        content = content.replace(target, replacement)
        with open('lib/dashboard_page.dart', 'w', encoding='utf-8') as f:
            f.write(content)
        print("Success")
    else:
        print("Target not found")

if __name__ == '__main__':
    main()
