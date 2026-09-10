import pathlib
import sys

from pypdf import PdfReader


source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
report = PdfReader(source)
text = "\n\n".join(
    f"=== PAGE {index + 1} ===\n{page.extract_text() or ''}"
    for index, page in enumerate(report.pages)
)
print(f"pages={len(report.pages)}", flush=True)
target.write_text(text, encoding="utf-8")
