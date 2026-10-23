import fs from 'node:fs/promises';
import { Workbook, SpreadsheetFile } from '@oai/artifact-tool';

const rows = JSON.parse(await fs.readFile(new URL('./localization_rows.json', import.meta.url), 'utf8'));
const workbook = Workbook.create();
const sheet = workbook.worksheets.add('StoryCompleteness');
const headers = ['LanguageKey', 'Simplified Chinese', 'English', 'Japanese', 'Traditional Chinese'];
sheet.getRange(`A1:E${rows.length + 1}`).values = [headers, ...rows];
sheet.showGridLines = false;
sheet.freezePanes.freezeRows(1);
sheet.getRange(`A1:E${rows.length + 1}`).format.font = { name: 'Arial', size: 10, color: '#242424' };
sheet.getRange(`A1:E${rows.length + 1}`).format.wrapText = true;
sheet.getRange(`A1:E${rows.length + 1}`).format.verticalAlignment = 'center';
sheet.getRange('A:E').format.columnWidthPx = 420;
sheet.getRange(`A2:E${rows.length + 1}`).format.rowHeightPx = 100;
sheet.getRange('A1:E1').format = {
  fill: '#574334', font: { name: 'Arial', size: 10, bold: true, color: '#FFFFFF' },
  rowHeightPx: 30, horizontalAlignment: 'center', verticalAlignment: 'center',
};
workbook.recalculate();
const preview = await workbook.render({ sheetName: sheet.name, range: 'A1:C5', scale: 1, format: 'png' });
await fs.writeFile(new URL('./translation_preview.png', import.meta.url), new Uint8Array(await preview.arrayBuffer()));
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save('Excel/Localization/StoryCompleteness.xlsx');
const values = sheet.getRange(`A2:E${rows.length + 1}`).values;
if (JSON.stringify(values) !== JSON.stringify(rows)) throw new Error('Localization rows changed during export');
console.log(`Exported ${rows.length} four-language entries`);
