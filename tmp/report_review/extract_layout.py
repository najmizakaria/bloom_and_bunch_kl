import pathlib
import sys
from pypdf import PdfReader

reader = PdfReader(sys.argv[1])
parts = []
for index, page in enumerate(reader.pages):
    try:
        text = page.extract_text(extraction_mode="layout") or ""
    except Exception:
        text = page.extract_text() or ""
    parts.append(f"=== PAGE {index + 1} ===\n{text}")
pathlib.Path(sys.argv[2]).write_text("\n\n".join(parts), encoding="utf-8")
print(len(reader.pages))
