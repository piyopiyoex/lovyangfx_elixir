defmodule LovyanGFX.Color do
  @moduledoc """
  Color normalization helpers for LovyanGFX commands.

  The normalized representation is a 16-bit RGB565 integer because it matches
  common LovyanGFX tutorial constants such as `TFT_RED` and framebuffer-oriented
  drawing.
  """

  @named_colors %{
    black: 0x0000,
    tft_black: 0x0000,
    white: 0xFFFF,
    tft_white: 0xFFFF,
    red: 0xF800,
    tft_red: 0xF800,
    green: 0x07E0,
    tft_green: 0x07E0,
    blue: 0x001F,
    tft_blue: 0x001F,
    yellow: 0xFFE0,
    tft_yellow: 0xFFE0,
    cyan: 0x07FF,
    tft_cyan: 0x07FF,
    magenta: 0xF81F,
    tft_magenta: 0xF81F,
    orange: 0xFD20,
    tft_orange: 0xFD20,
    purple: 0x8010,
    tft_purple: 0x8010,
    pink: 0xFC9F,
    navy: 0x000F,
    tft_navy: 0x000F,
    darkgreen: 0x03E0,
    tft_darkgreen: 0x03E0,
    dark_grey: 0x7BEF,
    dark_gray: 0x7BEF,
    light_grey: 0xC618,
    light_gray: 0xC618,
    grey: 0x8410,
    gray: 0x8410
  }

  @doc "Normalize a color into an RGB565 integer."
  def normalize(color) when is_atom(color) do
    case Map.fetch(@named_colors, color) do
      {:ok, rgb565} -> {:ok, rgb565}
      :error -> {:error, {:unknown_color, color}}
    end
  end

  def normalize({:rgb, red, green, blue}) do
    with :ok <- validate_channel(red),
         :ok <- validate_channel(green),
         :ok <- validate_channel(blue) do
      {:ok, rgb565(red, green, blue)}
    end
  end

  def normalize({:rgb565, color}) when is_integer(color) and color >= 0 and color <= 0xFFFF do
    {:ok, color}
  end

  def normalize({:rgb888, color}) when is_integer(color) and color >= 0 and color <= 0xFFFFFF do
    red = Bitwise.band(Bitwise.bsr(color, 16), 0xFF)
    green = Bitwise.band(Bitwise.bsr(color, 8), 0xFF)
    blue = Bitwise.band(color, 0xFF)

    {:ok, rgb565(red, green, blue)}
  end

  def normalize(color) when is_integer(color) and color >= 0 and color <= 0xFFFF do
    {:ok, color}
  end

  def normalize(color), do: {:error, {:invalid_color, color}}

  @doc "Convert 8-bit RGB channels into an RGB565 integer."
  def rgb565(red, green, blue) do
    red5 = Bitwise.bsr(red, 3)
    green6 = Bitwise.bsr(green, 2)
    blue5 = Bitwise.bsr(blue, 3)

    Bitwise.bsl(red5, 11) + Bitwise.bsl(green6, 5) + blue5
  end

  defp validate_channel(channel) when is_integer(channel) and channel >= 0 and channel <= 255,
    do: :ok

  defp validate_channel(channel), do: {:error, {:invalid_rgb_channel, channel}}
end
