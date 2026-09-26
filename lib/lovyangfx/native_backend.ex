defmodule LovyanGFX.NativeBackend do
  @moduledoc false

  @behaviour LovyanGFX.Backend

  @impl true
  def start(opts) do
    LovyanGFX.Native.start(opts[:width], opts[:height], opts[:framebuffer])
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
    LovyanGFX.Native.moving_icons_start(opts[:width], opts[:height], opts[:framebuffer])
  end

  @impl true
  def moving_icons_timings, do: LovyanGFX.Native.moving_icons_timings()

  @impl true
  def moving_icons_set_status(text), do: LovyanGFX.Native.moving_icons_set_status(text)

  @impl true
  def moving_icons_set_touch(text), do: LovyanGFX.Native.moving_icons_set_touch(text)

  @impl true
  def moving_icons_stop, do: LovyanGFX.Native.moving_icons_stop()
end
