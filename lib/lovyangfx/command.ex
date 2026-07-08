defmodule LovyanGFX.Command do
  @moduledoc false

  @doc "Normalize and validate a list of public render commands."
  def normalize(commands), do: normalize_commands(commands, [])

  defp normalize_commands([], acc), do: {:ok, Enum.reverse(acc)}

  defp normalize_commands([command | rest], acc) do
    case normalize_command(command) do
      {:ok, normalized_command} -> normalize_commands(rest, [normalized_command | acc])
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_command({:clear, color}), do: normalize_colored_1(:fill_screen, color)
  defp normalize_command({:fill_screen, color}), do: normalize_colored_1(:fill_screen, color)

  defp normalize_command({:draw_pixel, x, y, color}) do
    with :ok <- validate_ints([x, y]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {:draw_pixel, x, y, rgb565}}
    end
  end

  defp normalize_command({:draw_line, x0, y0, x1, y1, color}) do
    with :ok <- validate_ints([x0, y0, x1, y1]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {:draw_line, x0, y0, x1, y1, rgb565}}
    end
  end

  defp normalize_command({:draw_fast_hline, x, y, width, color}) do
    normalize_colored_4(:draw_fast_hline, x, y, width, color)
  end

  defp normalize_command({:draw_fast_vline, x, y, height, color}) do
    normalize_colored_4(:draw_fast_vline, x, y, height, color)
  end

  defp normalize_command({:draw_rect, x, y, width, height, color}) do
    normalize_colored_5(:draw_rect, x, y, width, height, color)
  end

  defp normalize_command({:fill_rect, x, y, width, height, color}) do
    normalize_colored_5(:fill_rect, x, y, width, height, color)
  end

  defp normalize_command({:draw_round_rect, x, y, width, height, radius, color}) do
    normalize_colored_6(:draw_round_rect, x, y, width, height, radius, color)
  end

  defp normalize_command({:fill_round_rect, x, y, width, height, radius, color}) do
    normalize_colored_6(:fill_round_rect, x, y, width, height, radius, color)
  end

  defp normalize_command({:draw_circle, x, y, radius, color}) do
    normalize_colored_4(:draw_circle, x, y, radius, color)
  end

  defp normalize_command({:fill_circle, x, y, radius, color}) do
    normalize_colored_4(:fill_circle, x, y, radius, color)
  end

  defp normalize_command({:draw_triangle, x0, y0, x1, y1, x2, y2, color}) do
    normalize_triangle(:draw_triangle, x0, y0, x1, y1, x2, y2, color)
  end

  defp normalize_command({:fill_triangle, x0, y0, x1, y1, x2, y2, color}) do
    normalize_triangle(:fill_triangle, x0, y0, x1, y1, x2, y2, color)
  end

  defp normalize_command({:push_image, x, y, width, height, rgb565_binary}) do
    normalize_rgb565_image(:push_image, x, y, width, height, rgb565_binary)
  end

  defp normalize_command({:push_rgb565, x, y, width, height, rgb565_binary}) do
    normalize_rgb565_image(:push_rgb565, x, y, width, height, rgb565_binary)
  end

  defp normalize_command({:push_grayscale, x, y, width, height, grayscale_binary}) do
    with :ok <- validate_ints([x, y]),
         :ok <- validate_positive_int(width),
         :ok <- validate_positive_int(height),
         :ok <- validate_binary_size(grayscale_binary, width * height) do
      {:ok, {:push_grayscale, x, y, width, height, grayscale_binary}}
    end
  end

  defp normalize_command({:draw_jpg, image_binary, x, y}) do
    normalize_encoded_image(:draw_jpg, image_binary, x, y)
  end

  defp normalize_command({:draw_png, image_binary, x, y}) do
    normalize_encoded_image(:draw_png, image_binary, x, y)
  end

  defp normalize_command({:draw_bmp, image_binary, x, y}) do
    normalize_encoded_image(:draw_bmp, image_binary, x, y)
  end

  defp normalize_command({:draw_qoi, image_binary, x, y}) do
    normalize_encoded_image(:draw_qoi, image_binary, x, y)
  end

  defp normalize_command({:draw_jpg_file, path, x, y}) do
    normalize_image_file_command(:draw_jpg_file, path, x, y)
  end

  defp normalize_command({:draw_png_file, path, x, y}) do
    normalize_image_file_command(:draw_png_file, path, x, y)
  end

  defp normalize_command({:draw_bmp_file, path, x, y}) do
    normalize_image_file_command(:draw_bmp_file, path, x, y)
  end

  defp normalize_command({:draw_qoi_file, path, x, y}) do
    normalize_image_file_command(:draw_qoi_file, path, x, y)
  end

  defp normalize_command({:create_sprite, name, width, height}) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_positive_int(width),
         :ok <- validate_positive_int(height) do
      {:ok, {:create_sprite, name, width, height}}
    end
  end

  defp normalize_command({:create_sprite, name, width, height, color_depth}) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_positive_int(width),
         :ok <- validate_positive_int(height),
         :ok <- validate_color_depth(color_depth) do
      {:ok, {:create_sprite, name, width, height, color_depth}}
    end
  end

  defp normalize_command({:delete_sprite, name}) do
    with :ok <- validate_sprite_name(name) do
      {:ok, {:delete_sprite, name}}
    end
  end

  defp normalize_command({:target, :screen}), do: {:ok, {:target, :screen}}

  defp normalize_command({:target, name}) do
    with :ok <- validate_sprite_name(name) do
      {:ok, {:target, name}}
    end
  end

  defp normalize_command({:push_sprite, name, x, y}) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_ints([x, y]) do
      {:ok, {:push_sprite, name, x, y}}
    end
  end

  defp normalize_command({:push_sprite_with_key_color, name, x, y, color}) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_ints([x, y]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {:push_sprite_with_key_color, name, x, y, rgb565}}
    end
  end

  defp normalize_command({:push_rotate_zoom, name, x, y, angle, zoom_x, zoom_y}) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_numbers([x, y, angle, zoom_x, zoom_y]),
         :ok <- validate_positive_number(zoom_x),
         :ok <- validate_positive_number(zoom_y) do
      {:ok, {:push_rotate_zoom, name, x, y, angle, zoom_x, zoom_y}}
    end
  end

  defp normalize_command(
         {:push_rotate_zoom, name, x, y, angle, zoom_x, zoom_y, transparent_color}
       ) do
    with :ok <- validate_sprite_name(name),
         :ok <- validate_numbers([x, y, angle, zoom_x, zoom_y]),
         :ok <- validate_positive_number(zoom_x),
         :ok <- validate_positive_number(zoom_y),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(transparent_color) do
      {:ok, {:push_rotate_zoom, name, x, y, angle, zoom_x, zoom_y, rgb565}}
    end
  end

  defp normalize_command({:set_font, font}) do
    with {:ok, normalized_font} <- LovyanGFX.Font.normalize(font) do
      {:ok, {:set_font, normalized_font}}
    end
  end

  defp normalize_command({:set_text_size, size}) do
    with :ok <- validate_positive_number(size) do
      {:ok, {:set_text_size, size}}
    end
  end

  defp normalize_command({:set_text_size, size_x, size_y}) do
    with :ok <- validate_positive_number(size_x),
         :ok <- validate_positive_number(size_y) do
      {:ok, {:set_text_size, size_x, size_y}}
    end
  end

  defp normalize_command({:set_text_color, color}) do
    with {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {:set_text_color, rgb565}}
    end
  end

  defp normalize_command({:set_text_color, color, background_color}) do
    with {:ok, rgb565} <- LovyanGFX.Color.normalize(color),
         {:ok, background_rgb565} <- LovyanGFX.Color.normalize(background_color) do
      {:ok, {:set_text_color, rgb565, background_rgb565}}
    end
  end

  defp normalize_command({:set_text_datum, datum}) do
    with {:ok, normalized_datum} <- LovyanGFX.TextDatum.normalize(datum) do
      {:ok, {:set_text_datum, normalized_datum}}
    end
  end

  defp normalize_command({:set_text_padding, padding}) do
    with :ok <- validate_non_negative_int(padding) do
      {:ok, {:set_text_padding, padding}}
    end
  end

  defp normalize_command({:set_rotation, rotation}) do
    with :ok <- validate_rotation(rotation) do
      {:ok, {:set_rotation, rotation}}
    end
  end

  defp normalize_command({:set_color_depth, depth}) do
    with :ok <- validate_color_depth(depth) do
      {:ok, {:set_color_depth, depth}}
    end
  end

  defp normalize_command({:set_cursor, x, y}) do
    with :ok <- validate_ints([x, y]) do
      {:ok, {:set_cursor, x, y}}
    end
  end

  defp normalize_command({:draw_string, text, x, y}) when is_binary(text) do
    with :ok <- validate_ints([x, y]) do
      {:ok, {:draw_string, text, x, y}}
    end
  end

  defp normalize_command({:draw_string, text, x, y, font}) when is_binary(text) do
    with :ok <- validate_ints([x, y]),
         {:ok, normalized_font} <- LovyanGFX.Font.normalize(font) do
      {:ok, {:draw_string, text, x, y, normalized_font}}
    end
  end

  defp normalize_command({:draw_number, number, x, y}) when is_integer(number) do
    with :ok <- validate_ints([x, y]) do
      {:ok, {:draw_number, number, x, y}}
    end
  end

  defp normalize_command({:draw_number, number, x, y, font}) when is_integer(number) do
    with :ok <- validate_ints([x, y]),
         {:ok, normalized_font} <- LovyanGFX.Font.normalize(font) do
      {:ok, {:draw_number, number, x, y, normalized_font}}
    end
  end

  defp normalize_command({:draw_float, number, decimals, x, y}) when is_number(number) do
    with :ok <- validate_byte_int(decimals),
         :ok <- validate_ints([x, y]) do
      {:ok, {:draw_float, number, decimals, x, y}}
    end
  end

  defp normalize_command({:draw_float, number, decimals, x, y, font}) when is_number(number) do
    with :ok <- validate_byte_int(decimals),
         :ok <- validate_ints([x, y]),
         {:ok, normalized_font} <- LovyanGFX.Font.normalize(font) do
      {:ok, {:draw_float, number, decimals, x, y, normalized_font}}
    end
  end

  defp normalize_command({:print, text}) when is_binary(text), do: {:ok, {:print, text}}
  defp normalize_command({:println, text}) when is_binary(text), do: {:ok, {:println, text}}
  defp normalize_command(:display), do: {:ok, {:display}}
  defp normalize_command({:display}), do: {:ok, {:display}}

  defp normalize_command(command), do: {:error, {:invalid_command, command}}

  defp normalize_colored_1(operation, color) do
    with {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {operation, rgb565}}
    end
  end

  defp normalize_colored_4(operation, x, y, size, color) do
    with :ok <- validate_ints([x, y, size]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {operation, x, y, size, rgb565}}
    end
  end

  defp normalize_colored_5(operation, x, y, width, height, color) do
    with :ok <- validate_ints([x, y, width, height]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {operation, x, y, width, height, rgb565}}
    end
  end

  defp normalize_colored_6(operation, x, y, width, height, radius, color) do
    with :ok <- validate_ints([x, y, width, height, radius]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {operation, x, y, width, height, radius, rgb565}}
    end
  end

  defp normalize_triangle(operation, x0, y0, x1, y1, x2, y2, color) do
    with :ok <- validate_ints([x0, y0, x1, y1, x2, y2]),
         {:ok, rgb565} <- LovyanGFX.Color.normalize(color) do
      {:ok, {operation, x0, y0, x1, y1, x2, y2, rgb565}}
    end
  end

  defp normalize_rgb565_image(operation, x, y, width, height, rgb565_binary) do
    with :ok <- validate_ints([x, y]),
         :ok <- validate_positive_int(width),
         :ok <- validate_positive_int(height),
         :ok <- validate_binary_size(rgb565_binary, width * height * 2) do
      {:ok, {operation, x, y, width, height, rgb565_binary}}
    end
  end


  defp normalize_encoded_image(operation, image_binary, x, y) do
    with :ok <- validate_non_empty_binary(image_binary),
         :ok <- validate_ints([x, y]) do
      {:ok, {operation, image_binary, x, y}}
    end
  end

  defp normalize_image_file_command(operation, path, x, y) do
    with :ok <- validate_non_empty_path(path),
         :ok <- validate_ints([x, y]) do
      {:ok, {operation, path, x, y}}
    end
  end

  defp validate_sprite_name(name) when is_atom(name) and name != :screen, do: :ok

  defp validate_sprite_name(name)
       when is_binary(name) and byte_size(name) > 0 and name != "screen", do: :ok

  defp validate_sprite_name(name), do: {:error, {:invalid_sprite_name, name}}

  defp validate_numbers(values) do
    case Enum.find(values, &(not is_number(&1))) do
      nil -> :ok
      value -> {:error, {:expected_number, value}}
    end
  end

  defp validate_ints(values) do
    case Enum.find(values, &(not is_integer(&1))) do
      nil -> :ok
      value -> {:error, {:expected_integer, value}}
    end
  end

  defp validate_non_negative_int(value) when is_integer(value) and value >= 0, do: :ok
  defp validate_non_negative_int(value), do: {:error, {:expected_non_negative_integer, value}}

  defp validate_byte_int(value) when is_integer(value) and value >= 0 and value <= 255, do: :ok
  defp validate_byte_int(value), do: {:error, {:expected_byte_integer, value}}

  defp validate_positive_number(value) when is_number(value) and value > 0, do: :ok
  defp validate_positive_number(value), do: {:error, {:expected_positive_number, value}}

  defp validate_positive_int(value) when is_integer(value) and value > 0, do: :ok
  defp validate_positive_int(value), do: {:error, {:expected_positive_integer, value}}

  defp validate_rotation(rotation) when is_integer(rotation) and rotation >= 0 and rotation <= 7,
    do: :ok

  defp validate_rotation(rotation), do: {:error, {:expected_rotation_0_to_7, rotation}}

  defp validate_color_depth(depth) when depth in [1, 2, 4, 8, 16, 24], do: :ok
  defp validate_color_depth(depth), do: {:error, {:unsupported_color_depth, depth}}


  defp validate_non_empty_path(path) when is_binary(path) and byte_size(path) > 0, do: :ok
  defp validate_non_empty_path(path), do: {:error, {:expected_non_empty_path, path}}

  defp validate_non_empty_binary(binary) when is_binary(binary) and byte_size(binary) > 0, do: :ok
  defp validate_non_empty_binary(binary) when is_binary(binary), do: {:error, :expected_non_empty_binary}
  defp validate_non_empty_binary(value), do: {:error, {:expected_binary, value}}

  defp validate_binary_size(binary, expected_size) when is_binary(binary) do
    actual_size = byte_size(binary)

    if actual_size == expected_size do
      :ok
    else
      {:error, {:unexpected_binary_size, expected_size, actual_size}}
    end
  end

  defp validate_binary_size(value, _expected_size), do: {:error, {:expected_binary, value}}
end
