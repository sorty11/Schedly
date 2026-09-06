import os
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas
from reportlab.lib import colors

def generate_law_pdf(output_path):
    width, height = landscape(A4) # 841.89 x 595.28
    c = canvas.Canvas(output_path, pagesize=(width, height))

    font_bold = "Helvetica-Bold"
    font_regular = "Helvetica"

    # Layout dimensions
    table_left = 45
    table_right = 795
    table_w = table_right - table_left # 750
    
    # Header
    c.setFont(font_bold, 13)
    c.drawCentredString(width / 2, 560, "SVKM's NMIMS")
    c.setFont(font_bold, 11)
    c.drawCentredString(width / 2, 545, "School of Law, Hyderabad Campus")
    c.setFont(font_bold, 11)
    c.drawCentredString(width / 2, 530, "TIME-TABLE")
    c.setFont(font_bold, 9.5)
    c.drawCentredString(width / 2, 513, "B.A. LL. B (HONS.) (THIRD YEAR), SEMESTER-V (BATCH- 2024-29) – ACADEMIC YEAR 2026-27")
    c.setFont(font_bold, 8.5)
    c.drawRightString(table_right, 575, "WEF: 20.07.2026")

    # Column layout:
    # Col 0: Day column [45, 95] (w=50)
    # Col 1: 9.10-10.10 [95, 175] (w=80)
    # Col 2: 10.11-11.11 AM [175, 255] (w=80)
    # Col 3: 11.12-12.12 PM [255, 335] (w=80)
    # Col 4: 12.13-1.13 PM [335, 415] (w=80)
    # Col 5: LUNCH [415, 445] (w=30)
    # Col 6: 2-3 PM [445, 525] (w=80)
    # Col 7: 3.01-4.01 PM [525, 605] (w=80)
    # Col 8: 4.02-5.02 PM [605, 685] (w=80)
    # Col 9: 5.03-6.03 PM [685, 765] (w=80) -> total table_right = 765
    
    col_x = [45, 95, 175, 255, 335, 415, 445, 525, 605, 685, 765]
    
    col_headers = [
        "TIME",
        "9.10-10.10",
        "10.11-11.11 AM",
        "11.12-12.12 PM",
        "12.13-1.13 PM",
        "LUNCH",
        "2-3 PM",
        "3.01-4.01 PM",
        "4.02-5.02 PM",
        "5.03-6.03 PM"
    ]

    row_y = [490, 455, 405, 355, 305, 255, 205, 160] # Header + Mon, Tue, Wed, Thu, Fri, Sat
    
    # Draw header row
    top_y = row_y[0]
    bot_y = row_y[1]
    h = top_y - bot_y
    for ci in range(10):
        x1 = col_x[ci]
        x2 = col_x[ci+1]
        c.rect(x1, bot_y, x2 - x1, h, fill=0)
        c.setFont(font_bold, 8)
        c.drawCentredString((x1 + x2) / 2, bot_y + (h / 2) - 3, col_headers[ci])

    days_label = ["MON", "TUES", "WED", "THUR", "FRI", "SAT"]
    
    # Table data per day (8 periods, lunch is drawn separately)
    grid_data = {
        "MON": [
            ("Administrative Law", "Prof. Anurag"),
            ("Company Law II", "Prof. Veddant"),
            ("Environmental Law", "Prof. Alisha"),
            ("Company Law II", "Prof. Veddant"),
            ("Family Law II", "Prof. Ishant Jain"),
            ("CPC & Limitation Act", "Prof. Mayank Singh"),
            ("Environmental Law", "Prof. Alisha"),
            ("", "")
        ],
        "TUES": [
            ("Administrative Law", "Prof. Anurag"),
            ("Company Law II", "Prof. Veddant"),
            ("Sports Law", "Dr. Nishit"),
            ("Maritime Law", "Prof. Anurag"),
            ("Maritime Law", "Prof. Anurag"),
            ("CPC & Limitation Act", "Prof. Mayank Singh"),
            ("Family Law II", "Prof. Ishant Jain"),
            ("Sports Law", "Dr. Nishit")
        ],
        "WED": [
            ("Administrative Law", "Prof. Anurag"),
            ("BSA", "Prof. Anoushka"),
            ("Environmental Law", "Prof. Alisha"),
            ("BSA", "Prof. Anoushka"),
            ("Family Law II", "Prof. Ishant Jain"),
            ("CPC & Limitation Act", "Prof. Mayank Singh"),
            ("Environmental Law", "Prof. Alisha"),
            ("", "")
        ],
        "THUR": [
            ("Cyber Law", "Prof. Aakash Satyadeo"),
            ("BSA", "Prof. Anoushka"),
            ("Administrative Law (U)", "Prof. Anurag"),
            ("BSA", "Prof. Anoushka"),
            ("Company Law II", "Prof. Veddant"),
            ("CPC & Limitation Act", "Prof. Mayank Singh"),
            ("Family Law II", "Prof. Ishant Jain"),
            ("", "")
        ],
        "FRI": [
            ("Cyber Law", "Prof. Aakash Satyadeo"),
            ("BSA", "Prof. Anoushka"),
            ("Environmental Law (U)", "Prof. Alisha"),
            ("Media Law", "Prof. Alisha"),
            ("Family Law II", "Prof. Ishant Jain"),
            ("CPC & Limitation Act", "Prof. Mayank Singh"),
            ("Media Law", "Prof. Alisha"),
            ("Administrative Law", "Prof. Anurag")
        ],
        "SAT": [
            ("", ""), ("", ""), ("", ""), ("", ""), ("", ""), ("", ""), ("", ""), ("", "")
        ]
    }

    # Draw data rows
    for r_idx in range(6):
        d_top = row_y[r_idx + 1]
        d_bot = row_y[r_idx + 2]
        rh = d_top - d_bot
        day_str = days_label[r_idx]

        # Day cell (Col 0)
        c.rect(col_x[0], d_bot, col_x[1] - col_x[0], rh, fill=0)
        c.setFont(font_bold, 8.5)
        c.drawCentredString((col_x[0] + col_x[1]) / 2, d_bot + (rh / 2) - 3, day_str)

        # Lunch cell (Col 5)
        c.rect(col_x[5], d_bot, col_x[6] - col_x[5], rh, fill=0)
        c.setFont(font_bold, 7)
        c.drawCentredString((col_x[5] + col_x[6]) / 2, d_bot + (rh / 2) - 3, "LUNCH")

        # Academic cells (Col 1-4, 6-9)
        periods = grid_data[day_str]
        col_indices = [1, 2, 3, 4, 6, 7, 8, 9]

        for p_idx in range(8):
            ci = col_indices[p_idx]
            x1 = col_x[ci]
            x2 = col_x[ci+1]
            c.rect(x1, d_bot, x2 - x1, rh, fill=0)
            
            subj, fac = periods[p_idx]
            if subj:
                # Wrap or size font so subject stays cleanly inside column bounds
                c.setFont(font_bold, 7)
                cx = (x1 + x2) / 2
                if subj == "Administrative Law (U)":
                    c.drawCentredString(cx, d_bot + rh - 13, "Administrative Law")
                    c.drawCentredString(cx, d_bot + rh - 22, "(U)")
                elif subj == "Environmental Law (U)":
                    c.drawCentredString(cx, d_bot + rh - 13, "Environmental Law")
                    c.drawCentredString(cx, d_bot + rh - 22, "(U)")
                else:
                    c.drawCentredString(cx, d_bot + rh - 16, subj)
            if fac:
                c.setFont(font_regular, 6.5)
                c.drawCentredString((x1 + x2) / 2, d_bot + 10, fac)

    # Note
    c.setFont(font_bold, 8.5)
    c.drawString(table_left, 135, "Note: T-Theory; U-Tutorial")

    c.save()

if __name__ == "__main__":
    out = "test/fixtures/NMIMS_SOL_Timetable_Sample.pdf"
    os.makedirs("test/fixtures", exist_ok=True)
    generate_law_pdf(out)
    print("Generated:", out)
