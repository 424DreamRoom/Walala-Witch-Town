import fs from 'node:fs/promises';
import path from 'node:path';
import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const out = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const source = path.resolve(out, '../../Excel/Localization/Localization.xlsx');
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const sheet = workbook.worksheets.getItemAt(0);
const rows = JSON.parse(await fs.readFile(path.join(out, 'translation_rows.json'), 'utf8'));
const used = sheet.getUsedRange().values;
console.log((await workbook.inspect({kind:'sheet,table',maxChars:1200,tableMaxRows:2,tableMaxCols:5})).ndjson);
if (!process.argv.includes('--write')) {
  const preview = await workbook.render({sheetName:sheet.name,range:'A2242:E2247',scale:1,format:'png'});
  await fs.writeFile(path.join(out,'translations_before.png'),new Uint8Array(await preview.arrayBuffer()));
} else {
  const known = new Map(used.slice(1).map((row,index)=>[row[0],index+2]));
  const append = [];
  for (const row of rows) {
    const index = known.get(row[0]);
    if (index) sheet.getRange(`B${index}:E${index}`).values = [row.slice(1)];
    else append.push(row);
  }
  const first = used.length + 1;
  if (append.length) {
    if (sheet.tables.items.length) sheet.tables.items[0].rows.add(null,append);
    else sheet.getRange(`A${first}:E${first+append.length-1}`).values = append;
    const added = sheet.getRange(`A${first}:E${first+append.length-1}`);
    added.format.wrapText = true;
    added.format.verticalAlignment = 'top';
    added.format.autofitRows();
  }
  workbook.recalculate();
  console.log((await workbook.inspect({kind:'table',range:`${sheet.name}!A${first}:E${first+append.length-1}`,include:'values,formulas',maxChars:1500,tableMaxRows:2})).ndjson);
  const preview = await workbook.render({sheetName:sheet.name,range:`A${first}:E${first+3}`,scale:1,format:'png'});
  await fs.writeFile(path.join(out,'translations_after.png'),new Uint8Array(await preview.arrayBuffer()));
  const exported = await SpreadsheetFile.exportXlsx(workbook);
  const temporary = path.join(out,'updated.xlsx');
  await exported.save(temporary);
  await fs.rename(temporary,source);
  console.log(`Synchronized ${rows.length} rows (${append.length} added)`);
}
