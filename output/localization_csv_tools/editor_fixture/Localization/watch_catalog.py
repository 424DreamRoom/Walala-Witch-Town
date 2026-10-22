"""Watch saved XLSX files; no packages or Excel installation required."""
import hashlib
from pathlib import Path
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
SOURCE = BASE.parent / "Excel/Localization"


def watch():
    previous, last_error = None, None
    print(f"Watching {SOURCE}; Ctrl+C stops the watcher", flush=True)
    try:
        while True:
            try:
                current = tuple((str(path), hashlib.sha256(path.read_bytes()).hexdigest())
                                for path in sorted(SOURCE.rglob("*.xlsx")) if not path.name.startswith("~$"))
                if current != previous:
                    result = subprocess.run([sys.executable, str(BASE / "build_catalog.py")],
                                            capture_output=True, text=True, encoding="utf-8", errors="replace")
                    if result.returncode == 0:
                        print(result.stdout, end="", flush=True)
                        previous, last_error = current, None
                    elif result.stderr != last_error:
                        print(result.stderr, end="", file=sys.stderr, flush=True)
                        last_error = result.stderr
            except OSError as error:
                if str(error) != last_error:
                    print(error, file=sys.stderr, flush=True)
                    last_error = str(error)
            time.sleep(1)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(watch())
