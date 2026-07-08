defmodule LovyanGFX do
  @moduledoc """
  Elixir API for LovyanGFX framebuffer rendering.

  The consuming application must prepare the framebuffer device before calling
  `start/1`. For example, a Nerves app should load the display drivers, wait for
  `/dev/fb0`, and detach the framebuffer console if needed.
  """

  @doc """
  Initialize the LovyanGFX framebuffer target.

  Options:

    * `:width` - framebuffer width. Defaults to `800`.
    * `:height` - framebuffer height. Defaults to `480`.
    * `:framebuffer` - framebuffer device path. Defaults to `/dev/fb0`.
  """
  def start(opts \\ []) do
    with {:ok, normalized_opts} <- LovyanGFX.Options.normalize_display(opts) do
      LovyanGFX.Backend.impl().start(normalized_opts)
    end
  end

  @doc """
  Render a batch of LovyanGFX-style drawing commands.

  Examples:

      LovyanGFX.render([
        {:fill_screen, :black},
        {:set_text_color, :white},
        {:set_cursor, 10, 10},
        {:println, "Hello LovyanGFX"},
        {:draw_line, 0, 40, 200, 40, :red}
      ])

  """
  def render(commands) when is_list(commands) do
    case LovyanGFX.Command.normalize(commands) do
      {:ok, normalized_commands} -> LovyanGFX.Backend.impl().render(normalized_commands)
      {:error, reason} -> {:error, reason}
    end
  end

  def render(_commands), do: {:error, :commands_must_be_a_list}

  @doc "Return the current display width after initialization."
  def width, do: LovyanGFX.Backend.impl().width()

  @doc "Return the current display height after initialization."
  def height, do: LovyanGFX.Backend.impl().height()

  @doc "Return the current display rotation after initialization."
  def rotation, do: LovyanGFX.Backend.impl().rotation()

  @doc "Seconds since kernel boot at which the MovingIcons demo started."
  def timings, do: LovyanGFX.Examples.MovingIcons.timings()

  @doc "Set the system-info text shown by the MovingIcons demo."
  def set_status(text) when is_binary(text), do: LovyanGFX.Examples.MovingIcons.set_status(text)

  @doc "Set the touch-info text shown by the MovingIcons demo."
  def set_touch(text) when is_binary(text), do: LovyanGFX.Examples.MovingIcons.set_touch(text)
end
