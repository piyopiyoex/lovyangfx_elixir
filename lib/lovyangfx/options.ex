defmodule LovyanGFX.Options do
  @moduledoc false

  @default_width 800
  @default_height 480
  @default_framebuffer "/dev/fb0"
  @framebuffer_modes [:direct, :buffered_rgb565]

  @doc "Normalize display options for framebuffer-backed operations."
  def normalize_display(opts \\ [])

  def normalize_display(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      width = Keyword.get(opts, :width, @default_width)
      height = Keyword.get(opts, :height, @default_height)
      framebuffer = Keyword.get(opts, :framebuffer, @default_framebuffer)
      framebuffer_mode = Keyword.get(opts, :framebuffer_mode, :direct)
      swap_bytes = Keyword.get(opts, :swap_bytes, false)

      with :ok <- validate_positive_integer(:width, width),
           :ok <- validate_positive_integer(:height, height),
           :ok <- validate_framebuffer(framebuffer),
           :ok <- validate_framebuffer_mode(framebuffer_mode),
           :ok <- validate_boolean(:swap_bytes, swap_bytes) do
        normalized = [width: width, height: height, framebuffer: framebuffer]

        normalized =
          if Keyword.has_key?(opts, :framebuffer_mode) do
            normalized ++ [framebuffer_mode: framebuffer_mode]
          else
            normalized
          end

        normalized =
          if Keyword.has_key?(opts, :swap_bytes) do
            normalized ++ [swap_bytes: swap_bytes]
          else
            normalized
          end

        {:ok, normalized}
      end
    else
      {:error, :invalid_options}
    end
  end

  def normalize_display(_opts), do: {:error, :invalid_options}

  defp validate_positive_integer(_name, value) when is_integer(value) and value > 0, do: :ok
  defp validate_positive_integer(name, value), do: {:error, {:invalid_option, name, value}}

  defp validate_framebuffer(value) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_framebuffer(value), do: {:error, {:invalid_option, :framebuffer, value}}

  defp validate_framebuffer_mode(value) when value in @framebuffer_modes, do: :ok
  defp validate_framebuffer_mode(value), do: {:error, {:invalid_option, :framebuffer_mode, value}}

  defp validate_boolean(_name, value) when is_boolean(value), do: :ok
  defp validate_boolean(name, value), do: {:error, {:invalid_option, name, value}}
end
