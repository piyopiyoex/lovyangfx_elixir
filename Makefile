# Builds the LovyanGFX framebuffer renderer as an Erlang NIF.
#
# Driven by elixir_make. Nerves provides the cross toolchain via CC/CXX and the
# erl_nif headers via ERTS_INCLUDE_DIR.

PRIV_DIR  = $(MIX_APP_PATH)/priv
NIF_SO    = $(PRIV_DIR)/lovyangfx_nif.so
TOOLCHAIN_INFO = $(PRIV_DIR)/.lovyangfx_nif.toolchain

LGFX_REPO = https://github.com/lovyan03/LovyanGFX.git
LGFX_VERSION = 1.2.29
LGFX_DIR  = c_src/vendor/lovyangfx
LGFX_SRC  = $(LGFX_DIR)/src

# erl_nif include dir (elixir_make sets ERTS_INCLUDE_DIR; fall back to erl)
ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~ts/erts-~ts/include/", [code:root_dir(), erlang:system_info(version)]), halt().')

CXX ?= $(CROSSCOMPILE)-g++
TOOLCHAIN_ID = $(shell $(CXX) -dumpmachine 2>/dev/null || printf '%s' '$(CXX)')

# LovyanGFX Linux framebuffer build set (mirrors examples_for_PC/CMake_FrameBuffer)
LGFX_SOURCES = \
	$(wildcard $(LGFX_SRC)/lgfx/v1/*.cpp) \
	$(wildcard $(LGFX_SRC)/lgfx/v1/misc/*.cpp) \
	$(LGFX_SRC)/lgfx/v1/panel/Panel_Device.cpp \
	$(wildcard $(LGFX_SRC)/lgfx/v1/platforms/framebuffer/*.cpp) \
	$(wildcard $(LGFX_SRC)/lgfx/Fonts/efont/*.c) \
	$(wildcard $(LGFX_SRC)/lgfx/Fonts/IPA/*.c) \
	$(wildcard $(LGFX_SRC)/lgfx/Fonts/lvgl/*.c) \
	$(wildcard $(LGFX_SRC)/lgfx/utility/*.c) \
	$(wildcard $(LGFX_SRC)/lgfx/v1/lv_font/*.c)

NIF_SOURCES = c_src/lovyangfx_nif.cpp

CPPFLAGS = -DLGFX_USE_V1 -DLGFX_LINUX_FB \
	-I$(LGFX_SRC) -I$(ERTS_INCLUDE_DIR)
CXXFLAGS += -std=c++17 -O2 -fPIC -fvisibility=hidden -ffunction-sections -fdata-sections -Wno-deprecated-declarations
LDFLAGS  += -shared

# GNU ld flags used by Nerves/Linux toolchains. Keep non-Linux host builds
# source-compatible with the existing package.
ifneq (,$(findstring linux,$(TOOLCHAIN_ID)))
LDFLAGS  += -Wl,--gc-sections -s
endif
LDLIBS   += -lpthread

.PHONY: all clean FORCE

ifeq ($(LOVYANGFX_ELIXIR_SKIP_NATIVE),1)
all:
	@mkdir -p $(PRIV_DIR)
	@echo "Skipping LovyanGFX native build because LOVYANGFX_ELIXIR_SKIP_NATIVE=1"
else
all: $(NIF_SO)
endif

$(LGFX_DIR):
	@mkdir -p $(dir $(LGFX_DIR))
	@echo "Fetching LovyanGFX $(LGFX_VERSION)..."
	git clone --depth 1 --branch $(LGFX_VERSION) $(LGFX_REPO) $(LGFX_DIR)

$(TOOLCHAIN_INFO): FORCE
	@mkdir -p $(PRIV_DIR)
	@current='$(TOOLCHAIN_ID)'; \
	previous="$$(cat "$@" 2>/dev/null || true)"; \
	if [ "$$previous" != "$$current" ]; then \
		printf '%s\n' "$$current" > "$@"; \
	fi

$(NIF_SO): $(LGFX_DIR) $(NIF_SOURCES) c_src/icons.cpp $(TOOLCHAIN_INFO)
	@mkdir -p $(PRIV_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(NIF_SOURCES) $(LGFX_SOURCES) \
		$(LDFLAGS) $(LDLIBS) -o $(NIF_SO)

clean:
	$(RM) $(NIF_SO) $(TOOLCHAIN_INFO)
