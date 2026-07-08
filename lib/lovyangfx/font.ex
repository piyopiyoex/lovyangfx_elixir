defmodule LovyanGFX.Font do
  @moduledoc """
  Font normalization helpers for LovyanGFX commands.

  The first public set intentionally mirrors the common built-in LovyanGFX font
  names used in tutorials.
  """

  @fonts MapSet.new([
           :font0,
           :font2,
           :font4,
           :font6,
           :font7,
           :font8,
           :japan_gothic_8,
           :japan_gothic_12,
           :japan_gothic_16,
           :japan_gothic_20,
           :japan_gothic_24,
           :japan_gothic_28,
           :japan_gothic_32,
           :japan_gothic_36,
           :japan_gothic_40,
           :japan_mincho_8,
           :japan_mincho_12,
           :japan_mincho_16,
           :japan_mincho_20,
           :japan_mincho_24,
           :japan_mincho_28,
           :japan_mincho_32,
           :japan_mincho_36,
           :japan_mincho_40
         ])

  @doc "Normalize a supported font name."
  def normalize(font) when is_atom(font) do
    if MapSet.member?(@fonts, font) do
      {:ok, font}
    else
      {:error, {:unknown_font, font}}
    end
  end

  def normalize(font), do: {:error, {:invalid_font, font}}
end
