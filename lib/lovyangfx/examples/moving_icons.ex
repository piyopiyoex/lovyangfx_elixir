defmodule LovyanGFX.Examples.MovingIcons do
  @moduledoc """
  Native MovingIcons demo kept as a smoke test and example.

  This module intentionally stays outside the main `LovyanGFX.render/1` command
  API. It exercises sprites, rotation, zoom, and continuous animation while the
  basic command API is still growing.
  """

  def start(opts \\ []) do
    with {:ok, normalized_opts} <- LovyanGFX.Options.normalize_display(opts) do
      LovyanGFX.Backend.impl().moving_icons_start(normalized_opts)
    end
  end

  def stop do
    backend = LovyanGFX.Backend.impl()

    if function_exported?(backend, :moving_icons_stop, 0) do
      backend.moving_icons_stop()
    else
      :ok
    end
  end

  def timings, do: LovyanGFX.Backend.impl().moving_icons_timings()

  def set_status(text) when is_binary(text),
    do: LovyanGFX.Backend.impl().moving_icons_set_status(text)

  def set_touch(text) when is_binary(text),
    do: LovyanGFX.Backend.impl().moving_icons_set_touch(text)
end
