import Config

# Use the non-rendering backend when exploring the package directly with:
#
#     iex -S mix
#
# Consuming applications, including Nerves apps, can override this by setting
# `config :lovyangfx_elixir, backend: LovyanGFX.NativeBackend` in their own config.
config :lovyangfx_elixir,
  backend: LovyanGFX.NullBackend
