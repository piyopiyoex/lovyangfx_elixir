defmodule LovyanGFX.Options do
  @moduledoc false

  @default_width 800
  @default_height 480
  @default_framebuffer "/dev/fb0"

  @doc "Normalize display options for framebuffer-backed operations."
  def normalize_display(opts \\ [])

  def normalize_display(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      with :ok <- validate_positive_integer(:width, Keyword.get(opts, :width, @default_width)),
           :ok <- validate_positive_integer(:height, Keyword.get(opts, :height, @default_height)),
           :ok <- validate_framebuffer(Keyword.get(opts, :framebuffer, @default_framebuffer)) do
        {:ok,
         [
           width: Keyword.get(opts, :width, @default_width),
           height: Keyword.get(opts, :height, @default_height),
           framebuffer: Keyword.get(opts, :framebuffer, @default_framebuffer)
         ]}
      end
    else
      {:error, :invalid_options}
    end
  end

  def normalize_display(_opts), do: {:error, :invalid_options}

  defp validate_positive_integer(name, value) when is_integer(value) and value > 0, do: :ok
  defp validate_positive_integer(name, value), do: {:error, {:invalid_option, name, value}}

  defp validate_framebuffer(value) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_framebuffer(value), do: {:error, {:invalid_option, :framebuffer, value}}
end
