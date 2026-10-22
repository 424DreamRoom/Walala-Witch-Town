"""Isolated tests of real XLSX exports, invalid updates and saved-file watching."""
import csv
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from excel_catalog import HEADERS, NS, read_workbook

BASE = Path(__file__).resolve().parent
M = NS["m"]


def workbook_fixture(path, rows, headers=HEADERS, formula=False):
    """Minimal OOXML fixture, intentionally mixing sparse/inline/shared cells."""
    worksheet = ET.Element("worksheet", xmlns=M)
    data = ET.SubElement(worksheet, "sheetData")
    for number, values in enumerate([list(headers), *rows], 1):
        row = ET.SubElement(data, "row", r=str(number))
        for column, value in enumerate(values):
            if value is None:
                continue
            cell = ET.SubElement(row, "c", r=chr(65 + column) + str(number), t="inlineStr")
            if formula and number == 2 and column == 1:
                ET.SubElement(cell, "f").text = '"text"'
            ET.SubElement(ET.SubElement(cell, "is"), "t").text = value
    with ZipFile(path, "w") as archive:
        archive.writestr("xl/workbook.xml", '<workbook xmlns="' + M + '" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>')
        archive.writestr("xl/_rels/workbook.xml.rels", '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>')
        archive.writestr("xl/worksheets/sheet1.xml", ET.tostring(worksheet, encoding="utf-8"))


class ExcelCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="walala_csv_")
        self.root = Path(self.temporary.name)
        self.source = self.root / "Excel/Localization"
        self.source.mkdir(parents=True)
        self.code = self.root / "Localization"
        self.code.mkdir()
        for name in ("build_catalog.py", "excel_catalog.py", "watch_catalog.py"):
            shutil.copy2(BASE / name, self.code / name)
        (self.code / "localized_text.gd").write_text("extends RefCounted\n", encoding="utf-8")
        audio = self.root / "Sounds/Walala"
        audio.mkdir(parents=True)
        (audio / "audio_manager.gd").write_text("extends Node\n", encoding="utf-8")
        self.xlsx = self.source / "Localization.xlsx"
        self.csv = self.xlsx.with_suffix(".csv")
        self.row = ["MENU_READY", '[b]准备好了，"魔女"[/b]\n%s', '[b]Ready, "witch"[/b]\n%s', '[b]準備完了[/b]\n%s', '[b]準備好了[/b]\n%s']
        workbook_fixture(self.xlsx, [self.row])

    def tearDown(self):
        self.temporary.cleanup()

    def build(self, *arguments, success=True):
        result = subprocess.run([sys.executable, "-X", "utf8", str(self.code / "build_catalog.py"), *arguments],
                                capture_output=True, text=True, encoding="utf-8", timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def csv_rows(self):
        with self.csv.open(encoding="utf-8-sig", newline="") as source:
            return list(csv.reader(source))

    def test_reordered_headers_quotes_and_newlines(self):
        order = [2, 4, 0, 3, 1]
        workbook_fixture(self.xlsx, [[self.row[i] for i in order]], [HEADERS[i] for i in order])
        self.build()
        self.assertEqual(self.csv_rows(), [list(HEADERS), self.row])
        self.assertEqual(read_workbook(self.xlsx), [self.row])
        self.assertIn('importer="keep"', self.xlsx.with_suffix(".csv.import").read_text())

    def test_unchanged_export_does_not_rewrite(self):
        self.build()
        before = self.csv.stat().st_mtime_ns
        self.build()
        self.assertEqual(before, self.csv.stat().st_mtime_ns)

    def test_check_detects_stale_csv_without_writing(self):
        self.build()
        before = self.csv.read_bytes()
        self.row[2] = "[b]Updated[/b]\n%s"
        workbook_fixture(self.xlsx, [self.row])
        self.build("--check", success=False)
        self.assertEqual(before, self.csv.read_bytes())
        self.build()
        self.build("--check")
        self.assertEqual(self.csv_rows()[1], self.row)

    def test_duplicate_keys_across_workbooks_preserve_csv(self):
        self.build()
        before = self.csv.read_bytes()
        workbook_fixture(self.source / "Other.xlsx", [self.row])
        result = self.build(success=False)
        self.assertIn("Duplicate LanguageKey", result.stderr)
        self.assertEqual(before, self.csv.read_bytes())
        self.assertFalse((self.source / "Other.csv").exists())

    def test_invalid_headers_sparse_cells_formulas_and_placeholders(self):
        self.build()
        before = self.csv.read_bytes()
        variants = [(self.row, HEADERS[:-1], False),
                    ([*self.row[:3], None, self.row[4]], HEADERS, False),
                    (self.row, HEADERS, True),
                    ([*self.row[:2], "[b]Missing placeholder[/b]", *self.row[3:]], HEADERS, False),
                    ([*self.row[:2], "[i]Wrong tags[/i]\n%s", *self.row[3:]], HEADERS, False),
                    ([*self.row[:2], "Click here %s", *self.row[3:]], HEADERS, False)]
        for row, headers, formula in variants:
            with self.subTest(headers=headers, row=row, formula=formula):
                workbook_fixture(self.xlsx, [row], headers, formula)
                self.build(success=False)
                self.assertEqual(before, self.csv.read_bytes())

    def test_additional_workbooks_and_excel_lock_files(self):
        other = ["MENU_OTHER", "其他", "Other", "その他", "其他"]
        workbook_fixture(self.source / "Other.xlsx", [other])
        (self.source / "~$Localization.xlsx").write_bytes(b"Excel lock, not a workbook")
        self.build()
        self.assertTrue((self.source / "Other.csv").is_file())
        self.assertFalse((self.source / "~$Localization.csv").exists())

    def test_saved_workbook_watcher_detects_content_with_same_timestamp(self):
        self.build()
        log = self.root / "watch.log"
        with log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen([sys.executable, "-X", "utf8", str(self.code / "build_catalog.py"), "--watch"],
                                       stdout=output, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 8
                while "LOCALIZATION CSV" not in log.read_text(encoding="utf-8"):
                    self.assertLess(time.monotonic(), deadline, "Watcher did not start")
                    time.sleep(0.1)
                timestamp = self.xlsx.stat().st_mtime_ns
                self.row[2] = '[b]Newer, "witch"[/b]\n%s'
                workbook_fixture(self.xlsx, [self.row])
                os.utime(self.xlsx, ns=(timestamp, timestamp))
                deadline = time.monotonic() + 8
                while self.csv_rows()[1] != self.row:
                    self.assertLess(time.monotonic(), deadline, log.read_text(encoding="utf-8"))
                    time.sleep(0.1)
                self.assertEqual(self.xlsx.stat().st_mtime_ns, timestamp)
            finally:
                process.terminate()
                process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
