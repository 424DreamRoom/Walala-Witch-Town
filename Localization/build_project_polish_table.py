"""Maintain this revision's small translation table, then run build_catalog.py."""
from pathlib import Path
import json
from openpyxl import Workbook

ROOT = Path(__file__).resolve().parents[1]
rows = json.loads((ROOT/'Localization/project_polish_translations.json').read_text(encoding='utf-8'))
book = Workbook()
sheet = book.active
sheet.title = 'Town life'
sheet.append(['LanguageKey','Simplified Chinese','English','Japanese','Traditional Chinese'])
for index, (source, en, ja, traditional) in enumerate(rows):
    sheet.append([f'polish_{index+1:03d}', source, en, ja, traditional])
sheet.freeze_panes='C2'
sheet.auto_filter.ref=sheet.dimensions
for col in 'ABCDE': sheet.column_dimensions[col].width = 28 if col=='A' else 80
book.save(ROOT/'Excel/Localization/ProjectPolish.xlsx')
print('PROJECT POLISH TRANSLATIONS', len(rows))
