defmodule LovyanGFX.Native do
  @moduledoc false

  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:lovyangfx_elixir), ~c"lovyangfx_nif")
    :erlang.load_nif(path, 0)
  end

  def start(_width, _height, _framebuffer), do: :erlang.nif_error(:nif_not_loaded)
  def render(_commands), do: :erlang.nif_error(:nif_not_loaded)
  def width, do: :erlang.nif_error(:nif_not_loaded)
  def height, do: :erlang.nif_error(:nif_not_loaded)
  def rotation, do: :erlang.nif_error(:nif_not_loaded)

  def moving_icons_start(_width, _height, _framebuffer), do: :erlang.nif_error(:nif_not_loaded)
  def moving_icons_timings, do: :erlang.nif_error(:nif_not_loaded)
  def moving_icons_set_status(_text), do: :erlang.nif_error(:nif_not_loaded)
  def moving_icons_set_touch(_text), do: :erlang.nif_error(:nif_not_loaded)
end
