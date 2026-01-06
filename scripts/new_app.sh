#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/new_app.sh <app_name> [description]

Example:
  scripts/new_app.sh my_app "My custom LVGL app"

Notes:
  - app_name should be letters, digits, or underscore only.
  - This script creates src/app/<app_name>/ and updates:
      - src/app/app_entry.c
      - envsetup.sh
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

app_name="$1"
app_desc="${2:-Custom app: ${app_name}}"

if [[ ! "${app_name}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Invalid app_name '${app_name}'. Use letters, digits, and underscore only." >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/src/app/${app_name}"

if [[ -e "${app_dir}" ]]; then
    echo "App directory already exists: ${app_dir}" >&2
    exit 1
fi

lower_name="$(printf '%s' "${app_name}" | tr '[:upper:]' '[:lower:]')"
macro_name="$(printf '%s' "${app_name}" | sed 's/[^A-Za-z0-9_]/_/g' | tr '[:lower:]' '[:upper:]')"

mkdir -p "${app_dir}"

cat <<EOF > "${app_dir}/app.h"
#ifndef APP_${macro_name}_H
#define APP_${macro_name}_H

#ifdef __cplusplus
extern "C" {
#endif

void app_${lower_name}_run(void);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* APP_${macro_name}_H */
EOF

cat <<EOF > "${app_dir}/app.c"
#include "src/app/${app_name}/app.h"

#include "lvgl/lvgl.h"

void app_${lower_name}_ui_init(void);
void app_${lower_name}_model_init(void);
void app_${lower_name}_utils_init(void);

void app_${lower_name}_run(void)
{
    app_${lower_name}_utils_init();
    app_${lower_name}_model_init();
    app_${lower_name}_ui_init();
}
EOF

cat <<EOF > "${app_dir}/ui.c"
#include "lvgl/lvgl.h"

void app_${lower_name}_ui_init(void)
{
    /* TODO: build LVGL objects here */
    (void)lv_scr_act();
}
EOF

cat <<EOF > "${app_dir}/model.c"
#include "lvgl/lvgl.h"

void app_${lower_name}_model_init(void)
{
    /* TODO: load data / init model state */
    (void)lv_tick_get();
}
EOF

cat <<EOF > "${app_dir}/utils.c"
#include "lvgl/lvgl.h"

void app_${lower_name}_utils_init(void)
{
    /* TODO: init timers, helpers, etc. */
    (void)lv_timer_get_idle();
}
EOF

python3 - <<PY
from pathlib import Path

app_name = "${app_name}"
lower_name = "${lower_name}"
macro_name = "${macro_name}"
app_desc = "${app_desc}"
repo_root = Path("${repo_root}")

entry_path = repo_root / "src/app/app_entry.c"
text = entry_path.read_text(encoding="utf-8")

include_line = f'#include "src/app/{app_name}/app.h"'
if include_line not in text:
    needle = '#include "lvgl/demos/lv_demos.h"'
    if needle in text:
        text = text.replace(needle, needle + "\\n\\n" + include_line, 1)
    else:
        text = include_line + "\\n" + text

run_fn = f"static void run_{lower_name}_app(void)\\n{{\\n    app_{lower_name}_run();\\n}}\\n\\n"
if f"run_{lower_name}_app" not in text:
    marker = "void app_entry_run(void)"
    idx = text.find(marker)
    if idx != -1:
        text = text[:idx] + run_fn + text[idx:]

macro_guard = f"LVGL_APP_TARGET_{macro_name}"
branch = f"#elif defined({macro_guard})\\n    run_{lower_name}_app();\\n"
if macro_guard not in text:
    text = text.replace("#else\\n    run_widgets_demo();", branch + "#else\\n    run_widgets_demo();", 1)

entry_path.write_text(text, encoding="utf-8")

env_path = repo_root / "envsetup.sh"
env_text = env_path.read_text(encoding="utf-8")

menu_line = 'declare -a _LVGL_APP_MENU=('
start = env_text.find(menu_line)
if start != -1:
    end = env_text.find(")", start)
    if end != -1:
        head = env_text[:end]
        tail = env_text[end:]
        if app_name not in head:
            head = head.rstrip() + f' "{app_name}"'
        env_text = head + tail

desc_block = 'declare -A _LVGL_APP_DESC=('
desc_entry = f'    ["{app_name}"]="{app_desc}"\\n'
if f'["{app_name}"]' not in env_text:
    start = env_text.find(desc_block)
    if start != -1:
        end = env_text.find(")", start)
        if end != -1:
            env_text = env_text[:end] + desc_entry + env_text[end:]

env_path.write_text(env_text, encoding="utf-8")
PY

echo "Created app '${app_name}' under ${app_dir}"
echo "Updated src/app/app_entry.c and envsetup.sh"
