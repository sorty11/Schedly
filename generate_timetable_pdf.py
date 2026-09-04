import os
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas
from reportlab.lib import colors

def generate_pdf(output_path):
    # A4 landscape: width = 841.89, height = 595.28
    width, height = landscape(A4)
    c = canvas.Canvas(output_path, pagesize=(width, height))

    # Standard Times fonts matching official NMIMS format
    font_bold = "Times-Bold"
    font_regular = "Times-Roman"

    # Column X coordinates:
    # 0: S.No      [45, 80]   (w=35)
    # 1: From      [80, 165]  (w=85)
    # 2: To        [165, 250] (w=85)
    # 3: Monday    [250, 350] (w=100) -> matches [250, 350]
    # 4: Tuesday   [350, 420] (w=70)  -> matches [350, 420]
    # 5: Wednesday [420, 510] (w=90)  -> matches [420, 510]
    # 6: Thursday  [510, 590] (w=80)  -> matches [510, 590]
    # 7: Friday    [590, 660] (w=70)  -> matches [590, 660]
    # 8: Saturday  [660, 730] (w=70)  -> matches [660, 730]
    col_x = [45, 80, 165, 250, 350, 420, 510, 590, 660, 730]

    # Authentic Excel colors
    c_yellow = colors.HexColor("#D4AC0D")       # Excel Classroom & Lunch yellow
    c_lunch_yellow = colors.HexColor("#D4AC0D")
    c_green = colors.HexColor("#6E8E6C")        # Excel PEC-GPT muted sage green
    c_border = colors.HexColor("#222222")

    table_left = col_x[0]
    table_right = col_x[-1]

    # Header section (Rows 1 to 5)
    header_top = 565
    header_rows = [
        ("SVKM's NMIMS Deemed to be University", 14, font_bold),
        ("School of Technology Management & Engineering, Jadcherla (Hyderabad)", 11.5, font_bold),
        ("CLASS TIME TABLE (2026-27)", 10.5, font_bold),
    ]

    curr_y = header_top
    row_h_title = 20
    for text, sz, fn in header_rows:
        c.setStrokeColor(c_border)
        c.setLineWidth(0.75)
        c.rect(table_left, curr_y - row_h_title, table_right - table_left, row_h_title, fill=0)
        c.setFont(fn, sz)
        c.setFillColor(colors.black)
        c.drawCentredString((table_left + table_right) / 2, curr_y - row_h_title + 6, text)
        curr_y -= row_h_title

    # Row 4: Class, Semester, Classroom
    # Aligns perfectly with column dividers at X=250 (end of To) and X=510 (end of Wednesday)
    row_h_meta = 18
    c.rect(table_left, curr_y - row_h_meta, 250 - table_left, row_h_meta, fill=0)
    c.setFont(font_bold, 8.5)
    c.drawString(table_left + 4, curr_y - row_h_meta + 5, "Class: - 2nd Year B Tech- (CSEDS) Div-A")

    c.rect(250, curr_y - row_h_meta, 510 - 250, row_h_meta, fill=0)
    c.drawCentredString((250 + 510) / 2, curr_y - row_h_meta + 5, "Semester:-III")

    # Yellow fill for classroom
    c.setFillColor(c_yellow)
    c.rect(510, curr_y - row_h_meta, table_right - 510, row_h_meta, fill=1, stroke=1)
    c.setFillColor(colors.black)
    c.drawCentredString((510 + table_right) / 2, curr_y - row_h_meta + 5, "Class Room: 1417, 4th floor")
    curr_y -= row_h_meta

    # Row 5: Class in-charge, empty mid, w.e.f
    c.rect(table_left, curr_y - row_h_meta, 250 - table_left, row_h_meta, fill=0)
    c.setFont(font_bold, 8.5)
    c.drawString(table_left + 4, curr_y - row_h_meta + 5, "Class in-charge: - Dr. Amit Saini")

    c.rect(250, curr_y - row_h_meta, 510 - 250, row_h_meta, fill=0)

    c.rect(510, curr_y - row_h_meta, table_right - 510, row_h_meta, fill=0)
    c.setFont(font_regular, 8.5)
    c.drawCentredString((510 + table_right) / 2, curr_y - row_h_meta + 5, "w.e.f: 17-08-2026")
    curr_y -= row_h_meta

    # Table Header (Rows 8 & 9 in Excel)
    th_h = 16
    th_total_h = th_h * 2

    # S.No cell
    c.rect(col_x[0], curr_y - th_total_h, col_x[1] - col_x[0], th_total_h, fill=0)
    c.setFont(font_bold, 8.5)
    c.drawCentredString((col_x[0] + col_x[1]) / 2, curr_y - th_total_h + 11, "S.No")

    # Day Time Period top
    c.rect(col_x[1], curr_y - th_h, col_x[3] - col_x[1], th_h, fill=0)
    c.drawCentredString((col_x[1] + col_x[3]) / 2, curr_y - th_h + 5, "Day Time Period")

    # From & To bottom
    c.rect(col_x[1], curr_y - th_total_h, col_x[2] - col_x[1], th_h, fill=0)
    c.drawCentredString((col_x[1] + col_x[2]) / 2, curr_y - th_total_h + 5, "From")

    c.rect(col_x[2], curr_y - th_total_h, col_x[3] - col_x[2], th_h, fill=0)
    c.drawCentredString((col_x[2] + col_x[3]) / 2, curr_y - th_total_h + 5, "To")

    # Days (Monday to Saturday)
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    for i, day in enumerate(days):
        x1, x2 = col_x[3 + i], col_x[4 + i]
        c.rect(x1, curr_y - th_total_h, x2 - x1, th_total_h, fill=0)
        c.drawCentredString((x1 + x2) / 2, curr_y - th_total_h + 11, day)

    curr_y -= th_total_h

    # Period row heights
    row_height = 36
    lunch_height = 24

    periods = [
        {"sno": "1", "from": "9:15", "to": "10:15", "h": row_height, "is_lunch": False},
        {"sno": "2", "from": "10:15", "to": "11:15", "h": row_height, "is_lunch": False},
        {"sno": "3", "from": "11:15", "to": "12:15", "h": row_height, "is_lunch": False},
        {"sno": "4", "from": "12:15", "to": "1:00", "h": lunch_height, "is_lunch": True},
        {"sno": "5", "from": "1:00", "to": "2:00", "h": row_height, "is_lunch": False},
        {"sno": "6", "from": "2:00", "to": "3:00", "h": row_height, "is_lunch": False},
        {"sno": "7", "from": "3:00", "to": "4:00", "h": row_height, "is_lunch": False},
        {"sno": "8", "from": "4:00", "to": "5:00", "h": row_height, "is_lunch": False},
    ]

    grid_data = {
        "Monday": [
            "DSA",
            "Software Engineering",
            "DCCA",
            "Lunch Break",
            "PnS-A1 LAB-3/\nWDD-A2 LAB-2", # P5 & P6 merged
            "",
            "Python",
            "PEC-GPT"
        ],
        "Tuesday": [
            "PnS",
            "DSA",
            "Website Designing and\nDevelopment",
            "Lunch Break",
            "WDD-A1 LAB-2/\nIPS-A2 ENG LAB", # P5 & P6 merged
            "",
            "DCCA",
            ""
        ],
        "Wednesday": [
            "PnS",
            "IPS-A1 ENG LAB/\nDSA-A2 LAB-2", # P2 & P3 merged
            "",
            "Lunch Break",
            "Python A1 LAB-1/\nDCCA A2 LAB-6", # P5 & P6 merged
            "",
            "Software Engineering",
            ""
        ],
        "Thursday": [
            "TC Tut-A1",
            "Software Engineering",
            "DSA",
            "Lunch Break",
            "DCCA A1 LAB-6/\nPython A2 LAB-1", # P5 & P6 merged
            "",
            "TC Tut-A2",
            "PEC-GPT"
        ],
        "Friday": [
            "DCCA",
            "DSA A1 LAB-1/\nSE A2 LAB-3", # P2 & P3 merged
            "",
            "Lunch Break",
            "SE-A1 LAB-1/\nPnS-A2 HPC LAB", # P5 & P6 merged
            "",
            "",
            ""
        ],
        "Saturday": [
            "", "", "", "Lunch Break", "", "", "", ""
        ]
    }

    period_y = []
    p_curr_y = curr_y
    for p in periods:
        p_top = p_curr_y
        p_bot = p_curr_y - p["h"]
        p_center = (p_top + p_bot) / 2
        period_y.append((p_top, p_bot, p_center))
        p_curr_y = p_bot

    # Draw S.No, From, To
    for idx, p in enumerate(periods):
        p_top, p_bot, p_center = period_y[idx]
        h = p["h"]

        c.setStrokeColor(c_border)
        c.setLineWidth(0.75)
        if p["is_lunch"]:
            c.setFillColor(c_lunch_yellow)
            c.rect(col_x[0], p_bot, col_x[1] - col_x[0], h, fill=1, stroke=1)
        else:
            c.rect(col_x[0], p_bot, col_x[1] - col_x[0], h, fill=0)

        c.setFont(font_bold, 8)
        c.setFillColor(colors.black)
        c.drawCentredString((col_x[0] + col_x[1]) / 2, p_center - 3, p["sno"])

        if p["is_lunch"]:
            c.setFillColor(c_lunch_yellow)
            c.rect(col_x[1], p_bot, col_x[2] - col_x[1], h, fill=1, stroke=1)
        else:
            c.rect(col_x[1], p_bot, col_x[2] - col_x[1], h, fill=0)
        c.setFont(font_regular, 8)
        c.setFillColor(colors.black)
        c.drawCentredString((col_x[1] + col_x[2]) / 2, p_center - 3, p["from"])

        if p["is_lunch"]:
            c.setFillColor(c_lunch_yellow)
            c.rect(col_x[2], p_bot, col_x[3] - col_x[2], h, fill=1, stroke=1)
        else:
            c.rect(col_x[2], p_bot, col_x[3] - col_x[2], h, fill=0)
        c.drawCentredString((col_x[2] + col_x[3]) / 2, p_center - 3, p["to"])

    # Draw Lunch Break spanning Monday to Saturday
    p4_top, p4_bot, p4_center = period_y[3]
    c.setFillColor(c_lunch_yellow)
    c.rect(col_x[3], p4_bot, col_x[-1] - col_x[3], periods[3]["h"], fill=1, stroke=1)
    c.setFont(font_bold, 9)
    c.setFillColor(colors.black)
    c.drawCentredString((col_x[3] + col_x[-1]) / 2, p4_center - 3, "Lunch Break")

    # Helper to draw cell text
    def draw_cell_content(x1, x2, y_top, y_bot, text, bg_color=None):
        w = x2 - x1
        h = y_top - y_bot
        cx = (x1 + x2) / 2
        cy = (y_top + y_bot) / 2

        if bg_color:
            c.setFillColor(bg_color)
            c.rect(x1, y_bot, w, h, fill=1, stroke=1)
            c.setFillColor(colors.black)
        else:
            c.setStrokeColor(c_border)
            c.rect(x1, y_bot, w, h, fill=0)

        if not text:
            return

        lines = text.split("\n")
        # For narrow cells or longer text, adjust font size
        font_size = 7.0 if len(lines) >= 2 or len(text) > 16 else 7.5
        c.setFont(font_regular, font_size)
        if len(lines) == 1:
            c.drawCentredString(cx, cy - 2.5, lines[0])
        elif len(lines) == 2:
            c.drawCentredString(cx, cy + 3, lines[0])
            c.drawCentredString(cx, cy - 6.5, lines[1])
        elif len(lines) >= 3:
            c.drawCentredString(cx, cy + 7, lines[0])
            c.drawCentredString(cx, cy - 1.5, lines[1])
            c.drawCentredString(cx, cy - 10, lines[2])

    def draw_merged_lab_cell(x1, x2, slot_idx1, slot_idx2, text):
        y_top = period_y[slot_idx1][0]
        y_bot = period_y[slot_idx2][1]
        w = x2 - x1
        h = y_top - y_bot
        cx = (x1 + x2) / 2
        cy = (y_top + y_bot) / 2

        c.setStrokeColor(c_border)
        c.rect(x1, y_bot, w, h, fill=0)

        lines = text.split("\n")
        c.setFont(font_regular, 7.0)
        c.setFillColor(colors.black)
        if len(lines) == 1:
            c.drawCentredString(cx, cy - 2.5, lines[0])
        elif len(lines) >= 2:
            c.drawCentredString(cx, cy + 3.5, lines[0])
            c.drawCentredString(cx, cy - 6.5, lines[1])

    # Draw day cells:
    for d_idx, day in enumerate(days):
        x1, x2 = col_x[3 + d_idx], col_x[4 + d_idx]

        # Period 1 (idx 0)
        draw_cell_content(x1, x2, period_y[0][0], period_y[0][1], grid_data[day][0])

        # Period 2 & 3: Wed & Fri are merged
        if day in ["Wednesday", "Friday"]:
            draw_merged_lab_cell(x1, x2, 1, 2, grid_data[day][1])
        else:
            draw_cell_content(x1, x2, period_y[1][0], period_y[1][1], grid_data[day][1])
            draw_cell_content(x1, x2, period_y[2][0], period_y[2][1], grid_data[day][2])

        # Period 4 is lunch break (already drawn)

        # Period 5 & 6: Mon, Tue, Wed, Thu, Fri are merged labs
        if day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]:
            draw_merged_lab_cell(x1, x2, 4, 5, grid_data[day][4])
        else:
            draw_cell_content(x1, x2, period_y[4][0], period_y[4][1], grid_data[day][4])
            draw_cell_content(x1, x2, period_y[5][0], period_y[5][1], grid_data[day][5])

        # Period 7
        draw_cell_content(x1, x2, period_y[6][0], period_y[6][1], grid_data[day][6])

        # Period 8
        bg = c_green if grid_data[day][7] == "PEC-GPT" else None
        draw_cell_content(x1, x2, period_y[7][0], period_y[7][1], grid_data[day][7], bg_color=bg)

    c.save()
    print("PDF generated successfully at", output_path)

if __name__ == "__main__":
    import sys
    target = sys.argv[1] if len(sys.argv) > 1 else "test_timetable.pdf"
    generate_pdf(target)
