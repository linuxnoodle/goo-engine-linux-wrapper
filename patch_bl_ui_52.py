"""Apply the Goo Engine 5.2 UI-panel compatibility patch.

Goo Engine 4.4 registered its renderer under the engine id BLENDER_EEVEE
(display name "Goo Engine") alongside a stock EEVEE entry
(BLENDER_EEVEE_NEXT, display name "EEVEE").  The 5.2 port re-implements the
Goo feature set inside EEVEE-Next (BLENDER_EEVEE) and adds a dedicated
"Goo Engine" engine entry (BLENDER_GOO_ENGINE, see the
eevee_engine.cc / draw_context.cc / scene.cc / rna_scene.cc patches).

The UI panels are Python and gate visibility on
`context.engine in cls.COMPAT_ENGINES` (or equality checks).  They only
listed BLENDER_EEVEE, so selecting the Goo Engine entry emptied the
properties panels.  This script adds BLENDER_GOO_ENGINE to every
EEVEE-gated panel/setting.

Idempotent: lines that already mention BLENDER_GOO_ENGINE are untouched.

Usage:
    python3 patch_bl_ui_52.py <bl_ui_dir>
    # e.g. goo-engine/scripts/startup/bl_ui   (source tree; the build
    # installs these into bin/5.2/scripts/startup/bl_ui automatically)
"""
import os
import re
import sys

EQ = re.compile(r"==\s*'BLENDER_EEVEE'")
NEQ = re.compile(r"!=\s*'BLENDER_EEVEE'")


def patch_line(line: str) -> str:
    if "'BLENDER_GOO_ENGINE'" in line:
        return line
    if EQ.search(line):
        return EQ.sub("in {'BLENDER_EEVEE', 'BLENDER_GOO_ENGINE'}", line)
    if NEQ.search(line):
        return NEQ.sub("not in {'BLENDER_EEVEE', 'BLENDER_GOO_ENGINE'}", line)
    # inline engine sets: `engine in {'BLENDER_RENDER', 'BLENDER_EEVEE', ...}`
    if ("in {" in line or "not in {" in line) and "'BLENDER_EEVEE'" in line:
        return line.replace("'BLENDER_EEVEE'",
                            "'BLENDER_EEVEE', 'BLENDER_GOO_ENGINE'")
    if "COMPAT_ENGINES" in line and "'BLENDER_EEVEE'" in line:
        return line.replace("'BLENDER_EEVEE'",
                            "'BLENDER_EEVEE', 'BLENDER_GOO_ENGINE'")
    return line


def patch_file(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()
    out = []
    in_compat_block = False
    for l in lines:
        if "COMPAT_ENGINES" in l and "=" in l and "{" in l:
            in_compat_block = True
        if in_compat_block and "}" in l:
            in_compat_block = False
        if "'BLENDER_GOO_ENGINE'" not in l and in_compat_block and \
                "'BLENDER_EEVEE'" in l:
            l = l.replace("'BLENDER_EEVEE'",
                          "'BLENDER_EEVEE', 'BLENDER_GOO_ENGINE'")
        out.append(patch_line(l))
    if out != lines:
        with open(path, "w", encoding="utf-8") as fh:
            fh.writelines(out)
        return True
    return False


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_bl_ui_52.py <bl_ui_dir>")
        return 2
    root = sys.argv[1]
    patched = 0
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in filenames:
            if not fn.endswith(".py"):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                if "'BLENDER_EEVEE'" not in fh.read():
                    continue
            if patch_file(p):
                patched += 1
                print(f"patched: {os.path.relpath(p, root)}")
    print(f"patched {patched} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
