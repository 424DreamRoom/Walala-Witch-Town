import fs from 'node:fs/promises';
import path from 'node:path';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const root = process.cwd();
const out = path.join(root, 'output/localization_csv_tools');
const source = path.join(root, 'Excel/Localization/Localization.xlsx');
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const sheet = workbook.worksheets.getItemAt(0);
console.log((await workbook.inspect({ kind: 'sheet,table', maxChars: 1600, tableMaxRows: 3, tableMaxCols: 5 })).ndjson);
if (process.argv.includes('--append')) {
  const rows = JSON.parse(await fs.readFile(path.join(out, 'additional_rows.json'), 'utf8'));
  const first = sheet.getUsedRange().values.length + 1;
  if (sheet.tables.items.length) sheet.tables.items[0].rows.add(null, rows);
  else sheet.getRange(`A${first}:E${first + rows.length - 1}`).values = rows;
  sheet.getRange(`A${first}:E${first + rows.length - 1}`).format.wrapText = true;
  sheet.getRange(`A${first}:E${first + rows.length - 1}`).format.verticalAlignment = 'top';
  sheet.getRange(`A${first}:E${first + rows.length - 1}`).format.autofitRows();
  workbook.recalculate();
  console.log((await workbook.inspect({kind:'table',range:`${sheet.name}!A${first}:E${first + rows.length - 1}`,include:'values,formulas',maxChars:1500})).ndjson);
  const preview = await workbook.render({sheetName:sheet.name,range:`A${first}:E${first + rows.length - 1}`,scale:1,format:'png'});
  await fs.writeFile(path.join(out,'additional.png'),new Uint8Array(await preview.arrayBuffer()));
  const xlsx = await SpreadsheetFile.exportXlsx(workbook);
  const temporary = path.join(out,'updated.xlsx');
  await xlsx.save(temporary);
  await fs.rename(temporary,source);
  console.log(`Appended ${rows.length} translations`);
} else if (!process.argv.includes('--write')) {
  const preview = await workbook.render({ sheetName: sheet.name, range: 'A1:E3', scale: 1, format: 'png' });
  await fs.writeFile(path.join(out, 'before.png'), new Uint8Array(await preview.arrayBuffer()));
} else {
  const rows = JSON.parse(await fs.readFile(path.join(out, 'migration_rows.json'), 'utf8'));
  await fs.copyFile(source, path.join(out, 'original-template.xlsx'));
  if (sheet.tables.items.length) sheet.tables.items[0].rows.add(null, rows);
  else sheet.getRange(`A2:E${rows.length + 1}`).values = rows;
  // Extend the template's existing columns; keep the header and tab in place.
  sheet.getRange(`A2:E${rows.length + 1}`).format.wrapText = true;
  sheet.getRange(`A2:E${rows.length + 1}`).format.verticalAlignment = 'top';
  sheet.getRange('A1:E1').format.rowHeight = 30;
  sheet.getRange('A1:A1').format.columnWidth = 38;
  sheet.getRange('B1:E1').format.columnWidth = 48;
  sheet.getRange(`A2:E${rows.length + 1}`).format.autofitRows();
  sheet.freezePanes.freezeRows(1);
  workbook.recalculate();
  console.log((await workbook.inspect({kind:'table',range:`${sheet.name}!A1:E5`,include:'values,formulas',tableMaxRows:5,tableMaxCols:5,maxChars:2000})).ndjson);
  const preview = await workbook.render({ sheetName: sheet.name, range: 'A1:E7', scale: 1, format: 'png' });
  await fs.writeFile(path.join(out, 'after.png'), new Uint8Array(await preview.arrayBuffer()));
  const xlsx = await SpreadsheetFile.exportXlsx(workbook);
  await xlsx.save(source);
  console.log(`Migrated ${rows.length} entries to ${source}`);
}
