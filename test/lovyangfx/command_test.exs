defmodule LovyanGFX.CommandTest do
  use ExUnit.Case, async: true

  test "normalize/1 rewrites clear to fill_screen" do
    assert {:ok, [{:fill_screen, 0x0000}]} = LovyanGFX.Command.normalize([{:clear, :black}])
  end

  test "normalize/1 validates image binary sizes" do
    assert {:error, {:unexpected_binary_size, 8, 2}} =
             LovyanGFX.Command.normalize([{:push_rgb565, 0, 0, 2, 2, <<0, 1>>}])
  end


  test "normalize/1 accepts encoded image binary commands" do
    assert {:ok, [{:draw_png, <<1, 2, 3>>, 10, 20}]} =
             LovyanGFX.Command.normalize([{:draw_png, <<1, 2, 3>>, 10, 20}])
  end

  test "normalize/1 preserves image file commands for native handling" do
    path = Path.join(System.tmp_dir!(), "lovyangfx_command_test.png")

    assert {:ok, [{:draw_png_file, path, 5, 6}]} =
             LovyanGFX.Command.normalize([{:draw_png_file, path, 5, 6}])
  end

  test "normalize/1 validates image file paths before reaching native handling" do
    assert {:error, {:expected_non_empty_path, ""}} =
             LovyanGFX.Command.normalize([{:draw_png_file, "", 0, 0}])
  end

  test "normalize/1 validates sprite names" do
    assert {:error, {:invalid_sprite_name, :screen}} =
             LovyanGFX.Command.normalize([{:create_sprite, :screen, 10, 10}])
  end

  test "normalize/1 validates rotate zoom factors" do
    assert {:error, {:expected_positive_number, 0.0}} =
             LovyanGFX.Command.normalize([{:push_rotate_zoom, :sprite, 10, 10, 45.0, 0.0, 1.0}])
  end

  test "normalize/1 accepts display commands" do
    assert {:ok, [{:display}, {:display}]} = LovyanGFX.Command.normalize([:display, {:display}])
  end
end
