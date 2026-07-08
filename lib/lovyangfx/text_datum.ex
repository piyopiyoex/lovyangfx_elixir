defmodule LovyanGFX.TextDatum do
  @moduledoc """
  Text datum normalization helpers for LovyanGFX commands.
  """

  @datums MapSet.new([
            :top_left,
            :top_center,
            :top_centre,
            :top_right,
            :middle_left,
            :middle_center,
            :middle_centre,
            :middle_right,
            :bottom_left,
            :bottom_center,
            :bottom_centre,
            :bottom_right,
            :baseline_left,
            :baseline_center,
            :baseline_centre,
            :baseline_right
          ])

  @doc "Normalize a supported text datum name."
  def normalize(datum) when is_atom(datum) do
    if MapSet.member?(@datums, datum) do
      {:ok, datum}
    else
      {:error, {:unknown_text_datum, datum}}
    end
  end

  def normalize(datum), do: {:error, {:invalid_text_datum, datum}}
end
