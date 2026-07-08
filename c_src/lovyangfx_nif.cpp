// LovyanGFX framebuffer renderer exposed as an Erlang NIF.
//
// The reusable API initializes an already prepared Linux framebuffer and accepts
// a small set of tutorial-friendly drawing commands from Elixir. MovingIcons is
// kept as a native smoke-test/demo path, not as the main rendering abstraction.

#include <stdio.h>
#include <LovyanGFX.hpp>
#include <lgfx/v1/platforms/framebuffer/Panel_fb.hpp>

#include "icons.cpp"  // info[] / alert[] / closeX[]  (RGB565)

#include <erl_nif.h>
#include <thread>
#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <time.h>
#include <mutex>
#include <string>
#include <vector>
#include <memory>
#include <unordered_map>

class LGFX : public lgfx::LGFX_Device {
  lgfx::Panel_fb panel_;

 public:
  LGFX(int width = 320, int height = 240, const char* device_name = "/dev/fb0") {
    auto cfg = panel_.config();
    cfg.memory_width = width;
    cfg.panel_width = width;
    cfg.memory_height = height;
    cfg.panel_height = height;
    panel_.config(cfg);
    panel_.setDeviceName(device_name);
    setPanel(&panel_);
    _board = lgfx::board_t::board_FrameBuffer;
  }
};

// ---- shared display target --------------------------------------------------
static int g_screen_x = 800;
static int g_screen_y = 480;
static std::string g_device_name = "/dev/fb0";
static std::unique_ptr<LGFX> g_lcd;
static std::atomic<bool> g_lcd_inited{false};
static std::mutex g_lcd_mtx;

#define lcd (*g_lcd)

static std::unordered_map<std::string, std::unique_ptr<LGFX_Sprite>> g_sprites;
static std::string g_current_target = "screen";

static bool get_name(ErlNifEnv* env, ERL_NIF_TERM term, std::string& out);

static LGFX_Sprite* sprite_by_name(const std::string& name) {
  auto it = g_sprites.find(name);
  if (it == g_sprites.end()) return nullptr;
  return it->second.get();
}

static LovyanGFX* current_render_target() {
  if (g_current_target == "screen") return &lcd;
  return sprite_by_name(g_current_target);
}

static bool ensure_lcd_init() {
  bool expected = false;
  if (!g_lcd_inited.compare_exchange_strong(expected, true)) return false;

  g_lcd = std::make_unique<LGFX>(g_screen_x, g_screen_y, g_device_name.c_str());
  lcd.init();

  if (lcd.width() < lcd.height()) {
    lcd.setRotation(lcd.getRotation() ^ 1);
  }

  return true;
}

static void set_display_target(unsigned int width, unsigned int height, ErlNifBinary framebuffer) {
  g_screen_x = static_cast<int>(width);
  g_screen_y = static_cast<int>(height);
  g_device_name.assign(reinterpret_cast<const char*>(framebuffer.data), framebuffer.size);
}

static ERL_NIF_TERM atom(ErlNifEnv* env, const char* name) {
  return enif_make_atom(env, name);
}

static ERL_NIF_TERM ok(ErlNifEnv* env) {
  return atom(env, "ok");
}

static ERL_NIF_TERM error(ErlNifEnv* env, const char* reason) {
  return enif_make_tuple2(env, atom(env, "error"), atom(env, reason));
}

static bool get_uint_arg(ErlNifEnv* env, ERL_NIF_TERM term, unsigned int* out) {
  return enif_get_uint(env, term, out);
}

static bool get_int_arg(ErlNifEnv* env, ERL_NIF_TERM term, int* out) {
  return enif_get_int(env, term, out);
}

static bool get_long_arg(ErlNifEnv* env, ERL_NIF_TERM term, long* out) {
  return enif_get_long(env, term, out);
}

static bool get_double_arg(ErlNifEnv* env, ERL_NIF_TERM term, double* out) {
  int int_value;
  if (enif_get_int(env, term, &int_value)) {
    *out = static_cast<double>(int_value);
    return true;
  }

  return enif_get_double(env, term, out);
}

static bool get_atom_string(ErlNifEnv* env, ERL_NIF_TERM term, std::string& out) {
  char buf[64];
  if (!enif_get_atom(env, term, buf, sizeof(buf), ERL_NIF_LATIN1)) return false;
  out.assign(buf);
  return true;
}

static bool get_binary_string(ErlNifEnv* env, ERL_NIF_TERM term, std::string& out) {
  ErlNifBinary bin;
  if (!enif_inspect_binary(env, term, &bin)) return false;
  out.assign(reinterpret_cast<const char*>(bin.data), bin.size);
  return true;
}

static bool get_name(ErlNifEnv* env, ERL_NIF_TERM term, std::string& out) {
  return get_atom_string(env, term, out) || get_binary_string(env, term, out);
}

static bool get_color(ErlNifEnv* env, ERL_NIF_TERM term, uint32_t* out) {
  unsigned int color;
  if (!enif_get_uint(env, term, &color)) return false;
  *out = static_cast<uint32_t>(color);
  return true;
}

static uint16_t rgb565_from_gray(uint8_t gray) {
  uint16_t r = static_cast<uint16_t>(gray >> 3);
  uint16_t g = static_cast<uint16_t>(gray >> 2);
  uint16_t b = static_cast<uint16_t>(gray >> 3);
  return static_cast<uint16_t>((r << 11) | (g << 5) | b);
}

static bool get_command_tuple(ErlNifEnv* env, ERL_NIF_TERM term, int* arity, const ERL_NIF_TERM** tuple) {
  return enif_get_tuple(env, term, arity, tuple);
}

static const lgfx::IFont* font_from_name(const std::string& name) {
  if (name == "font0") return &fonts::Font0;
  if (name == "font2") return &fonts::Font2;
  if (name == "font4") return &fonts::Font4;
  if (name == "font6") return &fonts::Font6;
  if (name == "font7") return &fonts::Font7;
  if (name == "font8") return &fonts::Font8;

  if (name == "japan_gothic_8") return &fonts::lgfxJapanGothic_8;
  if (name == "japan_gothic_12") return &fonts::lgfxJapanGothic_12;
  if (name == "japan_gothic_16") return &fonts::lgfxJapanGothic_16;
  if (name == "japan_gothic_20") return &fonts::lgfxJapanGothic_20;
  if (name == "japan_gothic_24") return &fonts::lgfxJapanGothic_24;
  if (name == "japan_gothic_28") return &fonts::lgfxJapanGothic_28;
  if (name == "japan_gothic_32") return &fonts::lgfxJapanGothic_32;
  if (name == "japan_gothic_36") return &fonts::lgfxJapanGothic_36;
  if (name == "japan_gothic_40") return &fonts::lgfxJapanGothic_40;

  if (name == "japan_mincho_8") return &fonts::lgfxJapanMincho_8;
  if (name == "japan_mincho_12") return &fonts::lgfxJapanMincho_12;
  if (name == "japan_mincho_16") return &fonts::lgfxJapanMincho_16;
  if (name == "japan_mincho_20") return &fonts::lgfxJapanMincho_20;
  if (name == "japan_mincho_24") return &fonts::lgfxJapanMincho_24;
  if (name == "japan_mincho_28") return &fonts::lgfxJapanMincho_28;
  if (name == "japan_mincho_32") return &fonts::lgfxJapanMincho_32;
  if (name == "japan_mincho_36") return &fonts::lgfxJapanMincho_36;
  if (name == "japan_mincho_40") return &fonts::lgfxJapanMincho_40;

  return nullptr;
}

static bool text_datum_from_name(const std::string& name, textdatum_t* datum) {
  if (name == "top_left") { *datum = textdatum_t::top_left; return true; }
  if (name == "top_center" || name == "top_centre") { *datum = textdatum_t::top_center; return true; }
  if (name == "top_right") { *datum = textdatum_t::top_right; return true; }
  if (name == "middle_left") { *datum = textdatum_t::middle_left; return true; }
  if (name == "middle_center" || name == "middle_centre") { *datum = textdatum_t::middle_center; return true; }
  if (name == "middle_right") { *datum = textdatum_t::middle_right; return true; }
  if (name == "bottom_left") { *datum = textdatum_t::bottom_left; return true; }
  if (name == "bottom_center" || name == "bottom_centre") { *datum = textdatum_t::bottom_center; return true; }
  if (name == "bottom_right") { *datum = textdatum_t::bottom_right; return true; }
  if (name == "baseline_left") { *datum = textdatum_t::baseline_left; return true; }
  if (name == "baseline_center" || name == "baseline_centre") { *datum = textdatum_t::baseline_center; return true; }
  if (name == "baseline_right") { *datum = textdatum_t::baseline_right; return true; }

  return false;
}

// ---- render command execution ----------------------------------------------
static bool execute_command(ErlNifEnv* env, ERL_NIF_TERM command, const char** error_reason) {
  int arity = 0;
  const ERL_NIF_TERM* tuple = nullptr;
  if (!get_command_tuple(env, command, &arity, &tuple) || arity < 1) {
    *error_reason = "invalid_command";
    return false;
  }

  std::string op;
  if (!get_atom_string(env, tuple[0], op)) {
    *error_reason = "invalid_operation";
    return false;
  }

  int x = 0, y = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0, w = 0, h = 0, r = 0;
  int decimals = 0, padding = 0;
  long number = 0;
  double number_f = 0.0, size_x = 1.0, size_y = 1.0;
  double dst_x = 0.0, dst_y = 0.0, angle = 0.0, zoom_x = 1.0, zoom_y = 1.0;
  uint32_t color = 0, bg_color = 0;
  std::string text;
  std::string font_name;
  std::string sprite_name;
  ErlNifBinary image_binary;
  const lgfx::IFont* font = nullptr;

  if (op == "create_sprite" && (arity == 4 || arity == 5)) {
    int depth = lcd.getColorDepth();
    if (!get_name(env, tuple[1], sprite_name) || sprite_name == "screen" ||
        !get_int_arg(env, tuple[2], &w) || !get_int_arg(env, tuple[3], &h)) {
      *error_reason = "invalid_create_sprite";
      return false;
    }
    if (arity == 5 && !get_int_arg(env, tuple[4], &depth)) {
      *error_reason = "invalid_create_sprite_depth";
      return false;
    }
    if (w <= 0 || h <= 0) {
      *error_reason = "invalid_sprite_size";
      return false;
    }

    auto sprite = std::make_unique<LGFX_Sprite>(&lcd);
    sprite->setColorDepth(depth);
    if (!sprite->createSprite(w, h)) {
      *error_reason = "create_sprite_failed";
      return false;
    }
    g_sprites[sprite_name] = std::move(sprite);
    return true;
  }

  if (op == "delete_sprite" && arity == 2) {
    if (!get_name(env, tuple[1], sprite_name) || sprite_name == "screen") {
      *error_reason = "invalid_delete_sprite";
      return false;
    }
    if (g_current_target == sprite_name) g_current_target = "screen";
    g_sprites.erase(sprite_name);
    return true;
  }

  if (op == "target" && arity == 2) {
    if (!get_name(env, tuple[1], sprite_name)) {
      *error_reason = "invalid_target";
      return false;
    }
    if (sprite_name == "screen") {
      g_current_target = "screen";
      return true;
    }
    if (sprite_by_name(sprite_name) == nullptr) {
      *error_reason = "unknown_sprite";
      return false;
    }
    g_current_target = sprite_name;
    return true;
  }

  if (op == "push_sprite" && arity == 4) {
    if (!get_name(env, tuple[1], sprite_name) || !get_int_arg(env, tuple[2], &x) || !get_int_arg(env, tuple[3], &y)) {
      *error_reason = "invalid_push_sprite";
      return false;
    }
    LGFX_Sprite* sprite = sprite_by_name(sprite_name);
    if (sprite == nullptr) { *error_reason = "unknown_sprite"; return false; }
    sprite->pushSprite(&lcd, x, y);
    return true;
  }

  if (op == "push_sprite_with_key_color" && arity == 5) {
    if (!get_name(env, tuple[1], sprite_name) || !get_int_arg(env, tuple[2], &x) ||
        !get_int_arg(env, tuple[3], &y) || !get_color(env, tuple[4], &color)) {
      *error_reason = "invalid_push_sprite_with_key_color";
      return false;
    }
    LGFX_Sprite* sprite = sprite_by_name(sprite_name);
    if (sprite == nullptr) { *error_reason = "unknown_sprite"; return false; }
    sprite->pushSprite(&lcd, x, y, color);
    return true;
  }

  if (op == "push_rotate_zoom" && (arity == 7 || arity == 8)) {
    if (!get_name(env, tuple[1], sprite_name) || !get_double_arg(env, tuple[2], &dst_x) ||
        !get_double_arg(env, tuple[3], &dst_y) || !get_double_arg(env, tuple[4], &angle) ||
        !get_double_arg(env, tuple[5], &zoom_x) || !get_double_arg(env, tuple[6], &zoom_y)) {
      *error_reason = "invalid_push_rotate_zoom";
      return false;
    }
    LGFX_Sprite* sprite = sprite_by_name(sprite_name);
    if (sprite == nullptr) { *error_reason = "unknown_sprite"; return false; }
    if (arity == 8) {
      if (!get_color(env, tuple[7], &color)) { *error_reason = "invalid_key_color"; return false; }
      sprite->pushRotateZoom(&lcd, static_cast<float>(dst_x), static_cast<float>(dst_y),
                             static_cast<float>(angle), static_cast<float>(zoom_x), static_cast<float>(zoom_y), color);
    } else {
      sprite->pushRotateZoom(&lcd, static_cast<float>(dst_x), static_cast<float>(dst_y),
                             static_cast<float>(angle), static_cast<float>(zoom_x), static_cast<float>(zoom_y));
    }
    return true;
  }

  LovyanGFX* target = current_render_target();
  if (target == nullptr) {
    *error_reason = "unknown_target";
    return false;
  }

  if ((op == "fill_screen" || op == "clear") && arity == 2) {
    if (!get_color(env, tuple[1], &color)) { *error_reason = "invalid_color"; return false; }
    target->fillScreen(color);
    return true;
  }

  if (op == "draw_pixel" && arity == 4) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) || !get_color(env, tuple[3], &color)) {
      *error_reason = "invalid_draw_pixel";
      return false;
    }
    target->drawPixel(x, y, color);
    return true;
  }

  if (op == "draw_line" && arity == 6) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &x1) || !get_int_arg(env, tuple[4], &y1) ||
        !get_color(env, tuple[5], &color)) {
      *error_reason = "invalid_draw_line";
      return false;
    }
    target->drawLine(x, y, x1, y1, color);
    return true;
  }

  if (op == "draw_fast_hline" && arity == 5) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &w) || !get_color(env, tuple[4], &color)) {
      *error_reason = "invalid_draw_fast_hline";
      return false;
    }
    target->drawFastHLine(x, y, w, color);
    return true;
  }

  if (op == "draw_fast_vline" && arity == 5) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &h) || !get_color(env, tuple[4], &color)) {
      *error_reason = "invalid_draw_fast_vline";
      return false;
    }
    target->drawFastVLine(x, y, h, color);
    return true;
  }

  if ((op == "draw_rect" || op == "fill_rect") && arity == 6) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &w) || !get_int_arg(env, tuple[4], &h) ||
        !get_color(env, tuple[5], &color)) {
      *error_reason = "invalid_rect";
      return false;
    }
    if (op == "draw_rect") target->drawRect(x, y, w, h, color);
    else target->fillRect(x, y, w, h, color);
    return true;
  }

  if ((op == "draw_round_rect" || op == "fill_round_rect") && arity == 7) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &w) || !get_int_arg(env, tuple[4], &h) ||
        !get_int_arg(env, tuple[5], &r) || !get_color(env, tuple[6], &color)) {
      *error_reason = "invalid_round_rect";
      return false;
    }
    if (op == "draw_round_rect") target->drawRoundRect(x, y, w, h, r, color);
    else target->fillRoundRect(x, y, w, h, r, color);
    return true;
  }

  if ((op == "draw_circle" || op == "fill_circle") && arity == 5) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &r) || !get_color(env, tuple[4], &color)) {
      *error_reason = "invalid_circle";
      return false;
    }
    if (op == "draw_circle") target->drawCircle(x, y, r, color);
    else target->fillCircle(x, y, r, color);
    return true;
  }

  if ((op == "draw_triangle" || op == "fill_triangle") && arity == 8) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &x1) || !get_int_arg(env, tuple[4], &y1) ||
        !get_int_arg(env, tuple[5], &x2) || !get_int_arg(env, tuple[6], &y2) ||
        !get_color(env, tuple[7], &color)) {
      *error_reason = "invalid_triangle";
      return false;
    }
    if (op == "draw_triangle") target->drawTriangle(x, y, x1, y1, x2, y2, color);
    else target->fillTriangle(x, y, x1, y1, x2, y2, color);
    return true;
  }

  if ((op == "push_image" || op == "push_rgb565") && arity == 6) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &w) || !get_int_arg(env, tuple[4], &h) ||
        !enif_inspect_binary(env, tuple[5], &image_binary)) {
      *error_reason = "invalid_rgb565_image";
      return false;
    }

    size_t expected_size = static_cast<size_t>(w) * static_cast<size_t>(h) * 2U;
    if (w <= 0 || h <= 0 || image_binary.size != expected_size) {
      *error_reason = "invalid_rgb565_image_size";
      return false;
    }

    size_t pixel_count = static_cast<size_t>(w) * static_cast<size_t>(h);
    std::vector<uint16_t> pixels(pixel_count);
    for (size_t i = 0; i < pixel_count; ++i) {
      uint8_t lo = image_binary.data[i * 2U];
      uint8_t hi = image_binary.data[i * 2U + 1U];
      pixels[i] = static_cast<uint16_t>(lo | (hi << 8));
    }

    target->pushImage(x, y, w, h, pixels.data());
    return true;
  }

  if (op == "push_grayscale" && arity == 6) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y) ||
        !get_int_arg(env, tuple[3], &w) || !get_int_arg(env, tuple[4], &h) ||
        !enif_inspect_binary(env, tuple[5], &image_binary)) {
      *error_reason = "invalid_grayscale_image";
      return false;
    }

    size_t expected_size = static_cast<size_t>(w) * static_cast<size_t>(h);
    if (w <= 0 || h <= 0 || image_binary.size != expected_size) {
      *error_reason = "invalid_grayscale_image_size";
      return false;
    }

    const uint8_t* pixels = reinterpret_cast<const uint8_t*>(image_binary.data);
    for (int row = 0; row < h; ++row) {
      for (int col = 0; col < w; ++col) {
        uint8_t gray = pixels[static_cast<size_t>(row) * static_cast<size_t>(w) + static_cast<size_t>(col)];
        target->drawPixel(x + col, y + row, rgb565_from_gray(gray));
      }
    }
    return true;
  }

  if ((op == "draw_jpg" || op == "draw_png" || op == "draw_bmp" || op == "draw_qoi") && arity == 4) {
    if (!enif_inspect_binary(env, tuple[1], &image_binary) ||
        !get_int_arg(env, tuple[2], &x) || !get_int_arg(env, tuple[3], &y)) {
      *error_reason = "invalid_draw_image";
      return false;
    }

    const uint8_t* image_data = reinterpret_cast<const uint8_t*>(image_binary.data);

    if (op == "draw_jpg") {
      target->drawJpg(image_data, image_binary.size, x, y);
      return true;
    }

    if (op == "draw_png") {
      target->drawPng(image_data, image_binary.size, x, y);
      return true;
    }

    if (op == "draw_bmp") {
      target->drawBmp(image_data, image_binary.size, x, y);
      return true;
    }

    target->drawQoi(image_data, image_binary.size, x, y);
    return true;
  }

  if ((op == "draw_jpg_file" || op == "draw_png_file" || op == "draw_bmp_file" || op == "draw_qoi_file") &&
      arity == 4) {
    if (!get_binary_string(env, tuple[1], text) ||
        !get_int_arg(env, tuple[2], &x) || !get_int_arg(env, tuple[3], &y)) {
      *error_reason = "invalid_draw_image_file";
      return false;
    }

    bool result = false;

    if (op == "draw_jpg_file") {
      result = target->drawJpgFile(text.c_str(), x, y);
    } else if (op == "draw_png_file") {
      result = target->drawPngFile(text.c_str(), x, y);
    } else if (op == "draw_bmp_file") {
      result = target->drawBmpFile(text.c_str(), x, y);
    } else {
      result = target->drawQoiFile(text.c_str(), x, y);
    }

    if (!result) {
      *error_reason = "draw_image_file_failed";
      return false;
    }

    return true;
  }

  if (op == "set_rotation" && arity == 2) {
    if (!get_int_arg(env, tuple[1], &r)) { *error_reason = "invalid_rotation"; return false; }
    target->setRotation(static_cast<uint8_t>(r));
    return true;
  }

  if (op == "set_color_depth" && arity == 2) {
    int depth = 0;
    if (!get_int_arg(env, tuple[1], &depth)) { *error_reason = "invalid_color_depth"; return false; }
    target->setColorDepth(depth);
    return true;
  }

  if (op == "set_font" && arity == 2) {
    if (!get_atom_string(env, tuple[1], text)) { *error_reason = "invalid_font"; return false; }
    font = font_from_name(text);
    if (font == nullptr) { *error_reason = "unknown_font"; return false; }
    target->setFont(font);
    return true;
  }

  if (op == "set_text_size" && arity == 2) {
    if (!get_double_arg(env, tuple[1], &size_x)) { *error_reason = "invalid_text_size"; return false; }
    target->setTextSize(static_cast<float>(size_x));
    return true;
  }

  if (op == "set_text_size" && arity == 3) {
    if (!get_double_arg(env, tuple[1], &size_x) || !get_double_arg(env, tuple[2], &size_y)) {
      *error_reason = "invalid_text_size";
      return false;
    }
    target->setTextSize(static_cast<float>(size_x), static_cast<float>(size_y));
    return true;
  }

  if (op == "set_text_color" && arity == 2) {
    if (!get_color(env, tuple[1], &color)) { *error_reason = "invalid_text_color"; return false; }
    target->setTextColor(color);
    return true;
  }

  if (op == "set_text_color" && arity == 3) {
    if (!get_color(env, tuple[1], &color) || !get_color(env, tuple[2], &bg_color)) {
      *error_reason = "invalid_text_color";
      return false;
    }
    target->setTextColor(color, bg_color);
    return true;
  }

  if (op == "set_text_datum" && arity == 2) {
    if (!get_atom_string(env, tuple[1], text)) { *error_reason = "invalid_text_datum"; return false; }
    textdatum_t datum;
    if (!text_datum_from_name(text, &datum)) { *error_reason = "unknown_text_datum"; return false; }
    target->setTextDatum(datum);
    return true;
  }

  if (op == "set_text_padding" && arity == 2) {
    if (!get_int_arg(env, tuple[1], &padding)) { *error_reason = "invalid_text_padding"; return false; }
    target->setTextPadding(static_cast<uint32_t>(padding));
    return true;
  }

  if (op == "set_cursor" && arity == 3) {
    if (!get_int_arg(env, tuple[1], &x) || !get_int_arg(env, tuple[2], &y)) {
      *error_reason = "invalid_cursor";
      return false;
    }
    target->setCursor(x, y);
    return true;
  }

  if ((op == "draw_string") && (arity == 4 || arity == 5)) {
    if (!get_binary_string(env, tuple[1], text) || !get_int_arg(env, tuple[2], &x) || !get_int_arg(env, tuple[3], &y)) {
      *error_reason = "invalid_draw_string";
      return false;
    }
    if (arity == 5) {
      if (!get_atom_string(env, tuple[4], font_name)) { *error_reason = "invalid_font"; return false; }
      font = font_from_name(font_name);
      if (font == nullptr) { *error_reason = "unknown_font"; return false; }
      target->drawString(text.c_str(), x, y, font);
    } else {
      target->drawString(text.c_str(), x, y);
    }
    return true;
  }

  if ((op == "draw_number") && (arity == 4 || arity == 5)) {
    if (!get_long_arg(env, tuple[1], &number) || !get_int_arg(env, tuple[2], &x) || !get_int_arg(env, tuple[3], &y)) {
      *error_reason = "invalid_draw_number";
      return false;
    }
    if (arity == 5) {
      if (!get_atom_string(env, tuple[4], font_name)) { *error_reason = "invalid_font"; return false; }
      font = font_from_name(font_name);
      if (font == nullptr) { *error_reason = "unknown_font"; return false; }
      target->drawNumber(number, x, y, font);
    } else {
      target->drawNumber(number, x, y);
    }
    return true;
  }

  if ((op == "draw_float") && (arity == 5 || arity == 6)) {
    if (!get_double_arg(env, tuple[1], &number_f) || !get_int_arg(env, tuple[2], &decimals) ||
        !get_int_arg(env, tuple[3], &x) || !get_int_arg(env, tuple[4], &y)) {
      *error_reason = "invalid_draw_float";
      return false;
    }
    if (arity == 6) {
      if (!get_atom_string(env, tuple[5], font_name)) { *error_reason = "invalid_font"; return false; }
      font = font_from_name(font_name);
      if (font == nullptr) { *error_reason = "unknown_font"; return false; }
      target->drawFloat(static_cast<float>(number_f), static_cast<uint8_t>(decimals), x, y, font);
    } else {
      target->drawFloat(static_cast<float>(number_f), static_cast<uint8_t>(decimals), x, y);
    }
    return true;
  }

  if (op == "print" && arity == 2) {
    if (!get_binary_string(env, tuple[1], text)) { *error_reason = "invalid_print"; return false; }
    target->print(text.c_str());
    return true;
  }

  if (op == "println" && arity == 2) {
    if (!get_binary_string(env, tuple[1], text)) { *error_reason = "invalid_println"; return false; }
    target->println(text.c_str());
    return true;
  }

  if (op == "display" && arity == 1) {
    lcd.display();
    return true;
  }

  *error_reason = "unsupported_command";
  return false;
}

// ---- MovingIcons demo state -------------------------------------------------
static double g_anim_t = 0.0;

static std::mutex g_status_mtx;
static std::string g_status;

static std::mutex g_touch_mtx;
static std::string g_touch;

static double boot_seconds() {
  struct timespec ts;
  clock_gettime(CLOCK_BOOTTIME, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

#define ICON_SWAP_BYTES false

static constexpr unsigned short infoWidth = 32, infoHeight = 32;
static constexpr unsigned short alertWidth = 32, alertHeight = 32;
static constexpr unsigned short closeWidth = 32, closeHeight = 32;

static uint32_t sec, psec;
static size_t fps = 0, frame_count = 0;
static uint32_t lcd_width, lcd_height;

struct obj_info_t {
  int_fast16_t x, y, dx, dy;
  int_fast8_t img;
  float r, z, dr, dz;
  void move() {
    r += dr;
    x += dx;
    if (x < 0) { x = 0; if (dx < 0) dx = -dx; }
    else if (x >= (int)lcd_width) { x = lcd_width - 1; if (dx > 0) dx = -dx; }
    y += dy;
    if (y < 0) { y = 0; if (dy < 0) dy = -dy; }
    else if (y >= (int)lcd_height) { y = lcd_height - 1; if (dy > 0) dy = -dy; }
    z += dz;
    if (z < .5) { z = .5; if (dz < .0) dz = -dz; }
    else if (z >= 2.0) { z = 2.0; if (dz > .0) dz = -dz; }
  }
};

static constexpr size_t obj_count = 50;
static obj_info_t objects[obj_count];
static LGFX_Sprite sprites[2];
static LGFX_Sprite icons[3];
static int_fast16_t sprite_height;
static std::atomic<bool> g_moving_icons_running{false};

static void moving_icons_setup() {
  ensure_lcd_init();
  lcd_width = lcd.width();
  lcd_height = lcd.height();

  for (size_t i = 0; i < obj_count; ++i) {
    obj_info_t* a = &objects[i];
    a->img = i % 3;
    a->x = rand() % lcd_width;
    a->y = rand() % lcd_height;
    a->dx = ((rand() & 3) + 1) * (i & 1 ? 1 : -1);
    a->dy = ((rand() & 3) + 1) * (i & 2 ? 1 : -1);
    a->dr = ((rand() & 3) + 1) * (i & 2 ? 1 : -1);
    a->r = 0;
    a->z = (float)((rand() % 10) + 10) / 10;
    a->dz = (float)((rand() % 10) + 1) / 100;
  }

  uint32_t div = 2;
  for (;;) {
    sprite_height = (lcd_height + div - 1) / div;
    bool fail = false;
    for (uint32_t i = 0; !fail && i < 2; ++i) {
      sprites[i].setColorDepth(lcd.getColorDepth());
      sprites[i].setFont(&fonts::Font2);
      fail = !sprites[i].createSprite(lcd_width, sprite_height);
    }
    if (!fail) break;
    for (uint32_t i = 0; i < 2; ++i) sprites[i].deleteSprite();
    ++div;
  }

  icons[0].createSprite(infoWidth, infoHeight);
  icons[1].createSprite(alertWidth, alertHeight);
  icons[2].createSprite(closeWidth, closeHeight);
  icons[0].setSwapBytes(ICON_SWAP_BYTES);
  icons[1].setSwapBytes(ICON_SWAP_BYTES);
  icons[2].setSwapBytes(ICON_SWAP_BYTES);
  icons[0].pushImage(0, 0, infoWidth, infoHeight, info);
  icons[1].pushImage(0, 0, alertWidth, alertHeight, alert);
  icons[2].pushImage(0, 0, closeWidth, closeHeight, closeX);

  lcd.startWrite();
}

static void draw_corner_text(LGFX_Sprite& spr, int band_y, const std::string& s,
                             bool right, uint32_t color) {
  if (s.empty()) return;

  std::vector<std::string> lines;
  size_t start = 0, nl;
  while ((nl = s.find('\n', start)) != std::string::npos) {
    lines.push_back(s.substr(start, nl - start));
    start = nl + 1;
  }
  lines.push_back(s.substr(start));

  spr.setFont(&fonts::Font2);
  spr.setTextSize(1);
  const int lh = 16, pad = 4;
  const int n = (int)lines.size();
  const int box_top = (int)lcd_height - (n * lh + pad * 2);
  if (box_top - band_y >= sprite_height) return;

  spr.setTextColor(color);
  spr.setTextDatum(right ? textdatum_t::top_right : textdatum_t::top_left);
  const int x = right ? ((int)lcd_width - pad) : pad;
  for (int i = 0; i < n; i++) {
    int line_y = box_top + pad + i * lh;
    spr.drawString(lines[i].c_str(), x, line_y - band_y);
  }
}

static void draw_status(LGFX_Sprite& spr, int band_y) {
  std::string s;
  { std::lock_guard<std::mutex> lk(g_status_mtx); s = g_status; }
  draw_corner_text(spr, band_y, s, false, spr.color565(120, 255, 160));
}

static void draw_touch(LGFX_Sprite& spr, int band_y) {
  std::string s;
  { std::lock_guard<std::mutex> lk(g_touch_mtx); s = g_touch; }
  draw_corner_text(spr, band_y, s, true, spr.color565(255, 230, 0));
}

static void moving_icons_loop() {
  static uint8_t flip = 0;
  for (size_t i = 0; i != obj_count; i++) objects[i].move();

  for (int_fast16_t y = 0; y < (int)lcd_height; y += sprite_height) {
    flip = flip ? 0 : 1;
    sprites[flip].clear();
    for (size_t i = 0; i != obj_count; i++) {
      obj_info_t* a = &objects[i];
      icons[a->img].pushRotateZoom(&sprites[flip], a->x, a->y - y, a->r, a->z, a->z, 0);
    }
    if (y == 0) {
      sprites[flip].setCursor(0, 0);
      sprites[flip].setFont(&fonts::Font4);
      sprites[flip].setTextColor(0xFFFFFFU);
      sprites[flip].printf("obj:%d  fps:%d", (int)obj_count, (int)fps);

      sprites[flip].setFont(&fonts::lgfxJapanGothic_24);
      sprites[flip].setTextColor(0xFFFFFFU);
      sprites[flip].setTextDatum(textdatum_t::top_right);
      sprites[flip].drawString("MovingIcons 実行中", lcd_width - 6, 2);
      sprites[flip].setTextDatum(textdatum_t::top_left);
    }

    draw_status(sprites[flip], y);
    draw_touch(sprites[flip], y);

    sprites[flip].pushSprite(&lcd, 0, y);
  }
  lcd.display();

  ++frame_count;
  sec = lgfx::millis() / 1000;
  if (psec != sec) {
    psec = sec;
    fps = frame_count;
    frame_count = 0;
  }
}

static void moving_icons_thread() {
  srand(12345);
  moving_icons_setup();
  g_anim_t = boot_seconds();
  for (;;) {
    moving_icons_loop();
    lgfx::delay(1);
  }
}

// ---- NIF glue ---------------------------------------------------------------
static bool parse_display_args(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[],
                               unsigned int* width, unsigned int* height, ErlNifBinary* framebuffer) {
  return argc == 3 &&
         get_uint_arg(env, argv[0], width) &&
         get_uint_arg(env, argv[1], height) &&
         enif_inspect_binary(env, argv[2], framebuffer);
}

static ERL_NIF_TERM start_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  unsigned int width;
  unsigned int height;
  ErlNifBinary framebuffer;

  if (!parse_display_args(env, argc, argv, &width, &height, &framebuffer)) {
    return enif_make_badarg(env);
  }

  std::lock_guard<std::mutex> lk(g_lcd_mtx);
  if (g_lcd_inited.load()) return atom(env, "already_started");

  set_display_target(width, height, framebuffer);
  ensure_lcd_init();
  return ok(env);
}

static ERL_NIF_TERM render_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  if (argc != 1) return enif_make_badarg(env);
  if (g_moving_icons_running.load()) return error(env, "moving_icons_running");

  std::lock_guard<std::mutex> lk(g_lcd_mtx);
  ensure_lcd_init();

  ERL_NIF_TERM list = argv[0];
  ERL_NIF_TERM head;
  ERL_NIF_TERM tail;

  g_current_target = "screen";
  lcd.startWrite();
  while (enif_get_list_cell(env, list, &head, &tail)) {
    const char* reason = nullptr;
    if (!execute_command(env, head, &reason)) {
      lcd.endWrite();
      return error(env, reason ? reason : "render_failed");
    }
    list = tail;
  }
  lcd.endWrite();
  lcd.display();

  return ok(env);
}

static ERL_NIF_TERM width_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM[]) {
  if (argc != 0) return enif_make_badarg(env);

  std::lock_guard<std::mutex> lk(g_lcd_mtx);
  ensure_lcd_init();
  return enif_make_int(env, lcd.width());
}

static ERL_NIF_TERM height_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM[]) {
  if (argc != 0) return enif_make_badarg(env);

  std::lock_guard<std::mutex> lk(g_lcd_mtx);
  ensure_lcd_init();
  return enif_make_int(env, lcd.height());
}

static ERL_NIF_TERM rotation_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM[]) {
  if (argc != 0) return enif_make_badarg(env);

  std::lock_guard<std::mutex> lk(g_lcd_mtx);
  ensure_lcd_init();
  return enif_make_int(env, lcd.getRotation());
}

static ERL_NIF_TERM moving_icons_start_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  unsigned int width;
  unsigned int height;
  ErlNifBinary framebuffer;

  if (!parse_display_args(env, argc, argv, &width, &height, &framebuffer)) {
    return enif_make_badarg(env);
  }

  bool expected = false;
  if (g_moving_icons_running.compare_exchange_strong(expected, true)) {
    if (!g_lcd_inited.load()) {
      set_display_target(width, height, framebuffer);
    }

    std::thread(moving_icons_thread).detach();
    return ok(env);
  }

  return atom(env, "already_started");
}

static ERL_NIF_TERM timings_nif(ErlNifEnv* env, int, const ERL_NIF_TERM[]) {
  return enif_make_double(env, g_anim_t);
}

static ERL_NIF_TERM set_text(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[],
                             std::mutex& mtx, std::string& dst) {
  ErlNifBinary bin;
  if (argc != 1 || !enif_inspect_binary(env, argv[0], &bin)) {
    return enif_make_badarg(env);
  }
  {
    std::lock_guard<std::mutex> lk(mtx);
    dst.assign((const char*)bin.data, bin.size);
  }
  return ok(env);
}

static ERL_NIF_TERM set_status_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return set_text(env, argc, argv, g_status_mtx, g_status);
}

static ERL_NIF_TERM set_touch_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  return set_text(env, argc, argv, g_touch_mtx, g_touch);
}

static int load(ErlNifEnv*, void**, ERL_NIF_TERM) { return 0; }

static ErlNifFunc nif_funcs[] = {
  {"start", 3, start_nif},
  {"render", 1, render_nif},
  {"width", 0, width_nif},
  {"height", 0, height_nif},
  {"rotation", 0, rotation_nif},
  {"moving_icons_start", 3, moving_icons_start_nif},
  {"moving_icons_timings", 0, timings_nif},
  {"moving_icons_set_status", 1, set_status_nif},
  {"moving_icons_set_touch", 1, set_touch_nif}
};

ERL_NIF_INIT(Elixir.LovyanGFX.Native, nif_funcs, load, NULL, NULL, NULL)
