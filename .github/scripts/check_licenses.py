"""Check the licensing declarations maintained by this fork."""

import hashlib
from pathlib import Path
import re
import sys


root = Path(__file__).resolve().parents[2]
# SHA-256 of https://www.gnu.org/licenses/gpl-3.0.txt, verified 2026-11-05.
expected_hash = "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986"
license_file = root / "LICENSE"
errors = []
if not license_file.is_file():
    errors.append("LICENSE is missing")
elif hashlib.sha256(license_file.read_bytes()).hexdigest() != expected_hash:
    errors.append("LICENSE differs from the verified GNU GPLv3 master text")

scripts = sorted(root.glob("*.m"))
if not scripts:
    errors.append("No root-level MATLAB files found")
for script in scripts:
    # Allow MATLAB help/license comments after a function declaration as well.
    header = []
    in_signature = False
    for line in script.read_text(encoding="utf-8-sig").splitlines():
        if line.lstrip().startswith("function ") or in_signature:
            in_signature = line.rstrip().endswith("...")
            continue
        if line.strip() and not line.lstrip().startswith("%"):
            break
        header.append(line)
    identifiers = re.findall(
        r"^\s*%\s*SPDX-License-Identifier:\s*(\S.*?)\s*$",
        "\n".join(header),
        re.MULTILINE,
    )
    if identifiers != ["GPL-3.0-only"]:
        errors.append(f"{script.name}: expected one GPL-3.0-only SPDX header")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"LICENSE matches the GNU master; {len(scripts)} MATLAB SPDX headers pass.")
