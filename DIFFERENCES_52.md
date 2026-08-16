# Goo Engine 5.2 branch — differences vs. the v4.4 wrapper

This branch (`v5.2-beta`) builds the
[NaMgAl-Studio/goo-engine-5.2.0](https://github.com/NaMgAl-Studio/goo-engine-5.2.0)
port: Goo Engine's NPR feature set re-implemented on Blender 5.2 / EEVEE-Next
(BSL shader pipeline). The v4.4 branch builds the original
[dillongoostudios/goo-engine](https://github.com/dillongoostudios/goo-engine)
(legacy EEVEE fork).

Everything below documents how this branch differs from `v4.4-release`, and
what was needed to get legacy Goo shader packs (files authored for goo-engine
4.4's legacy EEVEE) rendering correctly in the port.

---

## 1. Source, branch, libraries

| | v4.4 wrapper | v5.2 branch |
|---|---|---|
| Repo | dillongoostudios/goo-engine | NaMgAl-Studio/goo-engine-5.2.0 |
| Branch | `goo-engine-v4.4-release` | `main` |
| Blender base | 4.4.3 (legacy EEVEE) | 5.2.0 (EEVEE-Next, BSL) |
| Libraries | git LFS submodule (Blender repos) | same `make_update.py --use-linux-libraries` (git LFS submodule) |
| `lib/linux_x64/webp` | renamed to `libwebp` (v4.4 CMake expects `libwebp`) | **kept as `webp`** — 5.2 CMake expects `${LIBDIR}/webp`; do NOT rename |
| fallback datafiles | required (v4.4 shipped corrupt LFS pointers in release/datafiles) | **not needed** — 5.2 LFS pull delivers real binaries (`startup.blend` is Zstd, real icons/splash). Guard kept in script for parity. |

## 2. Build flags

```bash
# v4.4
make BUILD_CMAKE_ARGS="-DWITH_ASSERT_ABORT=OFF" -j$(nproc)

# v5.2 (this branch)
make BUILD_CMAKE_ARGS="-DWITH_ASSERT_ABORT=OFF \
                       -DWITH_GPU_SHADER_CPP_COMPILATION=OFF \
                       -DWITH_CYCLES_DEVICE_HIP=ON \
                       -DWITH_CYCLES_HIP_BINARIES=ON \
                       -DCYCLES_HIP_BINARIES_ARCH=gfx1030" -j$(nproc)
```

- **`WITH_GPU_SHADER_CPP_COMPILATION=OFF`** — required on GCC 16. The
  `bsl_shader_linting` dev target compiles all `.bsl.hh` shader headers as
  host C++; GCC 16 hard-errors on `ShadowRenderData{.shadow_random = ...}`
  ("member ... is uninitialized reference", a designated-initializer that
  skips the port's new `shadow_id_diagnostic` reference member). The
  linting target is dev-only; disabling it does not affect the shipped
  shaders.
- **HIP** — `WITH_CYCLES_DEVICE_HIP=ON` is on by default in the port; this
  branch also builds the runtime kernels
  (`WITH_CYCLES_HIP_BINARIES=ON`) for the AMD arch in `HIP_ARCH`
  (default `gfx1030` = RX 6950 XT). Requires ROCm (`hipcc`) on the build
  machine; set `HIP_ARCH=""` for CPU-only.
- The `make BUILD_CMAKE_ARGS=...` pattern works on a fresh checkout
  (cmake configures with the args on first run). Re-running with different
  args does NOT re-configure — clean with `reset_build.sh` first if you
  change flags.

## 3. Patches

The v4.4 patch set still applies to 5.2, minus the two library
patches the 5.2 libs already ship with (`GridBuilder.h` already uses
`mValueMask`; `OpenColorIO.h` already includes `<cstdint>`):

| patch | target | why |
|---|---|---|
| `childrenProxy.h` | lib/linux_x64/usd | adds `_PrimSet` (missing USD method; still needed in the 5.2 lib) |
| `buildinfo.c` | source/creator | TIFFFax symbol declarations (GCC) |

New 5.2 patches (this branch) — the **"Goo Engine" engine + black-material
fix**:

| patch | target | why |
|---|---|---|
| `eevee_engine.cc` / `.h` | draw/engines/eevee | registers `BLENDER_GOO_ENGINE` → display name **"Goo Engine"**, sharing EEVEE-Next's renderer (`eevee_render`), with `RE_USE_EEVEE_VIEWPORT` |
| `draw_context.cc` | draw/intern | registers the new engine type; routes its viewport draw to the EEVEE view-data |
| `scene.cc` | blenkernel | `RE_engine_id_BLENDER_GOO_ENGINE` const; `BKE_scene_uses_blender_eevee()` matches it |
| `DNA_scene_types.h` | makesdna | extern decl for the new engine id |
| `overlay_instance.cc` | draw/engines/overlay | depth-buffer availability check matches the goo id |
| `rna_scene.cc` | makesrna | static engine-items fallback includes the goo entry |
| `node_tree_zones.cc` | blenkernel | **black-material fix** — see below |
| `shader_nodes_inline.cc` | nodes/shader | **black-material fix** — see below |

Plus `patch_bl_ui_52.py` (run by the build script on
`scripts/startup/bl_ui`): adds `'BLENDER_GOO_ENGINE'` to every
`COMPAT_ENGINES` set and engine-equality check that gates on
`'BLENDER_EEVEE'` (~28 files, 363 panels). Without it, selecting
"Goo Engine" in the render-engine dropdown empties the Render Properties
panels (they are Python and only listed `BLENDER_EEVEE`).

### Why the "Goo Engine" engine entry exists

Goo Engine 4.4 registered its renderer as `BLENDER_EEVEE` with display name
**"Goo Engine"** and kept stock `BLENDER_EEVEE_NEXT` as **"EEVEE"** — two
distinct engines. The 5.2 port re-implements the Goo feature set *inside*
EEVEE-Next; there is no second implementation left to expose. So in the
port, `BLENDER_GOO_ENGINE` and `BLENDER_EEVEE` are the **same renderer**
(identical output). The goo entry exists for parity: legacy files/prefs
storing the goo engine id resolve, the dropdown matches goo-engine 4.4, and
goo-gated panels/scripts work. Selecting "EEVEE" also gives you the Goo
features — there is no clean stock-EEVEE option in the port.

### The black-material bug (the important one)

Legacy Goo shader packs can contain *structural* link cycles that Blender
flags `NODE_LINK_VALID = 0` at tree update, e.g.:

```
texture.Vector  <- NodeGroup.Vector output        (closing link, flagged invalid)
texture.Color   -> NodeGroup.color input           (valid)
```

`bNodeLink::is_available()` (and therefore
`has_available_link_cycle()`, `is_used()`, the toposort) **ignores**
`NODE_LINK_VALID`, so these trees are seen as cyclic:

1. `discover_tree_zones()` (`node_tree_zones.cc`) returned `nullptr` for
   the whole material tree;
2. `ShaderNodesInliner::find_trees_potentially_containing_shader_outputs_recursive()`
   bails on `zones() == nullptr`;
3. `do_inline()` produced an **empty tree (0 nodes)** → `ntreeGPUMaterialNodes`
   on nothing → **the entire material renders black**.

Legacy EEVEE skipped invalid links and rendered these files fine; the port
(and stock Blender 5.2, which has the same inliner) rendered them black —
matching the reported symptom exactly.

Fix (both patches needed):
- `node_tree_zones.cc`: `discover_tree_zones()` uses a VALID-aware cycle
  check (`has_cycle_ignoring_invalid_links`, Kahn's algorithm over
  `is_available() && NODE_LINK_VALID` links).
- `shader_nodes_inline.cc`: `link_is_usable()` (same predicate) used for the
  cycle checks and for every link traversal in the inliner, so invalid
  links are skipped exactly like legacy skipped them.

With these, previously-black materials inline fully and render correctly —
with zero file-level shader edits.

## 4. Runtime fixes

- **SYCL libs**: same as v4.4 — the binary won't launch without
  `libsycl.so.8` / `libur_loader.so.0` beside it. The build script copies
  them from `lib/linux_x64/dpcpp/lib` into `build_linux/bin/lib`.

## 5. Install / launcher

| | v4.4 wrapper | v5.2 branch |
|---|---|---|
| Install dir | `~/.local/share/goo-engine` | `~/.local/share/goo-engine-52` |
| Binary | `goo-engine` | `goo-engine-52` |
| Desktop entry | "Goo Engine" | "Goo Engine 5.2" |
| User resources | default (`~/.config/blender/4.4`, version-isolated) | **isolated via `BLENDER_USER_RESOURCES=$HOME/.config/goo-engine-52`** |

The 5.2 binary reports Blender version 5.2, so without the launcher wrapper
it would share `~/.config/blender/5.2` with any stock Blender 5.2 install
(prefs, addons, extensions, enabled-engine state). goo-engine 4.4 was
naturally isolated by its version dir; 5.2 needs the explicit wrapper.
(Do NOT let scripts write into `~/.local/bin/goo-engine-52` through a
symlink — a redirected heredoc over the symlink will overwrite the binary.
The install script writes a real launcher file.)

## 6. Known remaining limitations (vs. goo-engine 4.4)

- **Shader-to-RGB after a mixed transparent+emission closure**: the
  pattern some legacy Goo shader packs use for see-through effects (a
  material-level wrapper that Shader-to-RGBs a mixed closure and blends in
  behind-scene color) still evaluates differently in EEVEE-Next, darkening
  the surface in some poses. Re-linking the material Output directly past
  the wrapper reproduces the goo-4.4 look. Everything else — SDF shading,
  matcaps, textures — works from the port fix alone.
- **Screenspace Info / Shader to RGB semantics** after mixed closures
  diverge from legacy (the port's README documents SSI as
  "degrades gracefully per pass"). This is the remaining upstream gap.
- The port README itself: experimental build; "for production NPR work on
  Blender 4.4, use the original Goo Engine release".

## 7. Verification checklist

```bash
# build (fresh clone, ~30-60 min on 32 cores)
bash build_goo_engine_52.sh
bash install_goo_engine_52.sh

goo-engine-52 --version                       # "Blender 5.2.0 LTS"
goo-engine-52 --background --factory-startup --python-expr "
import bpy
print([i.name for i in bpy.types.Scene.bl_rna.properties['render']
       .fixed_type.properties['engine'].enum_items])"   # ['EEVEE', 'Goo Engine']
# (GUI: dropdown shows Goo Engine / EEVEE / Workbench / Cycles; all
#  Render Properties panels present under "Goo Engine")

# HIP devices
goo-engine-52 --background --factory-startup --python-expr "
import bpy; p=bpy.context.preferences.addons['cycles'].preferences
p.compute_device_type='HIP'; p.get_devices()
print([d.name for d in p.devices if d.type=='HIP'])"     # AMD Radeon RX 6950 XT

# legacy shader pack renders (was fully black before the port fix)
goo-engine-52 --background ~/Downloads/Zhu_Yuan_V1.3.blend \
    --python-expr "import bpy; bpy.context.scene.render.filepath='/tmp/zy.png'; bpy.ops.render.render(write_still=True)"
```

## Status

**EXPERIMENTAL — AI-GENERATED.** This branch was generated with AI assistance
and is derived from
[NaMgAl-Studio/goo-engine-5.2.0](https://github.com/NaMgAl-Studio/goo-engine-5.2.0)
(an unofficial Goo Engine → Blender 5.2 / EEVEE-Next port), itself derived from
dillongoostudios/goo-engine and Blender. No warranty; the upstream port's own
README recommends the original Goo Engine 4.4 for production NPR work.
