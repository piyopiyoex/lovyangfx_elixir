defmodule LovyanGFX.NativeBackend do
  @moduledoc false

  @behaviour LovyanGFX.Backend

  @impl true
  def start(opts) do
    if extended_display_options?(opts) do
      LovyanGFX.Native.start(
        opts[:width],
        opts[:height],
        opts[:framebuffer],
        Keyword.get(opts, :framebuffer_mode, :direct),
        Keyword.get(opts, :swap_bytes, false)
      )
    else
      LovyanGFX.Native.start(opts[:width], opts[:height], opts[:framebuffer])
    end
  end

  @impl true
  def render(commands), do: LovyanGFX.Native.render(commands)

  @impl true
  def width, do: LovyanGFX.Native.width()

  @impl true
  def height, do: LovyanGFX.Native.height()

  @impl true
  def rotation, do: LovyanGFX.Native.rotation()

  @impl true
  def moving_icons_start(opts) do
    if extended_display_options?(opts) do
      LovyanGFX.Native.moving_icons_start(
        opts[:width],
        opts[:height],
        opts[:framebuffer],
        Keyword.get(opts, :framebuffer_mode, :direct),
        Keyword.get(opts, :swap_bytes, false)
      )
    else
      LovyanGFX.Native.moving_icons_start(opts[:width], opts[:height], opts[:framebuffer])
    end
  end

  @impl true
  def moving_icons_timings, do: LovyanGFX.Native.moving_icons_timings()

  @impl true
  def moving_icons_set_status(text), do: LovyanGFX.Native.moving_icons_set_status(text)

  @impl true
  def moving_icons_set_touch(text), do: LovyanGFX.Native.moving_icons_set_touch(text)

  @impl true
  def moving_icons_stop, do: LovyanGFX.Native.moving_icons_stop()

  defp extended_display_options?(opts) do
    Keyword.has_key?(opts, :framebuffer_mode) or Keyword.has_key?(opts, :swap_bytes)
  end
end
