#include "src/app/template_app/app.h"

#include "lvgl/lvgl.h"

void app_template_ui_init(void);
void app_template_model_init(void);
void app_template_utils_init(void);

void app_template_run(void)
{
    app_template_utils_init();
    app_template_model_init();
    app_template_ui_init();
}
