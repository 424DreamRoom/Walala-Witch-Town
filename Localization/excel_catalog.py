"""Read localization XLSX tables without Excel or third-party packages."""
import csv
import io
import posixpath
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

HEADERS = ("LanguageKey", "Simplified Chinese", "English", "Japanese", "Traditional Chinese")
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def column_index(address):
    index = 0
    for letter in address:
        if not letter.isalpha():
            break
        index = index * 26 + ord(letter.upper()) - ord("A") + 1
    return index - 1


def read_workbook(path):
    """Combine data sheets with named columns; preserve all cell text."""
    rows = []
    with ZipFile(path) as archive:
        strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            strings = ["".join(si.itertext()) for si in ET.fromstring(
                archive.read("xl/sharedStrings.xml")).findall("m:si", NS)]
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relationships = {r.attrib["Id"]: r.attrib["Target"] for r in ET.fromstring(
            archive.read("xl/_rels/workbook.xml.rels"))}
        for sheet in workbook.findall("m:sheets/m:sheet", NS):
            target = relationships[sheet.attrib[f"{{{REL_NS}}}id"]]
            target = target.lstrip("/") if target.startswith("/") else posixpath.normpath("xl/" + target)
            tree = ET.fromstring(archive.read(target))
            order = None
            for row in tree.findall("m:sheetData/m:row", NS):
                cells = {}
                for cell in row.findall("m:c", NS):
                    address = cell.attrib["r"]
                    if cell.find("m:f", NS) is not None:
                        raise ValueError(f"{path.name}/{sheet.attrib['name']}!{address}: use literal text, not a formula")
                    value = cell.find("m:v", NS)
                    kind = cell.attrib.get("t")
                    if kind == "inlineStr":
                        value = "".join(cell.find("m:is", NS).itertext())
                    elif kind == "s":
                        value = strings[int(value.text)]
                    else:
                        value = value.text if value is not None else ""
                    if kind == "e":
                        raise ValueError(f"{path.name}!{address}: Excel error {value}")
                    cells[column_index(address)] = value or ""
                if not any(value.strip() for value in cells.values()):
                    continue
                if order is None:
                    named = {value.strip().lstrip("\ufeff"): index for index, value in cells.items() if value.strip()}
                    if len(named) != len(HEADERS) or set(named) != set(HEADERS) or len([v for v in cells.values() if v.strip()]) != len(HEADERS):
                        raise ValueError(f"{path.name}/{sheet.attrib['name']}: expected headers {HEADERS}, got {list(cells.values())}")
                    order = [named[header] for header in HEADERS]
                    continue
                if any(value.strip() and index not in order for index, value in cells.items()):
                    raise ValueError(f"{path.name}/{sheet.attrib['name']} row {row.attrib['r']}: data outside named columns")
                values = [cells.get(index, "") for index in order]
                if not all(value.strip() for value in values):
                    raise ValueError(f"{path.name}/{sheet.attrib['name']} row {row.attrib['r']}: incomplete translation")
                rows.append(values)
    if not rows:
        raise ValueError(f"{path.name}: no localization entries")
    return rows


def read_catalogs(directory):
    paths = sorted(path for path in Path(directory).rglob("*.xlsx") if not path.name.startswith("~$"))
    if not paths:
        raise ValueError(f"No localization XLSX tables in {directory}")
    return {path.with_suffix(".csv"): read_workbook(path) for path in paths}


def delimited_text(rows, headers=HEADERS, delimiter=","):
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, delimiter=delimiter, lineterminator="\n")
    writer.writerow(headers)
    writer.writerows(rows)
    return stream.getvalue()


def write_if_changed(path, text):
    """Replace complete outputs, keeping the last CSV intact on failure."""
    path = Path(path)
    data = text.encode("utf-8")
    if path.is_file() and path.read_bytes() == data:
        return False
    temporary = path.with_name(path.name + ".tmp")
    try:
        temporary.write_bytes(data)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)
    return True
