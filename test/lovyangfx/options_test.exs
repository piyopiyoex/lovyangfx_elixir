defmodule LovyanGFX.OptionsTest do
  use ExUnit.Case, async: true

  test "normalize_display/1 applies defaults" do
    assert {:ok, [width: 800, height: 480, framebuffer: "/dev/fb0"]} =
             LovyanGFX.Options.normalize_display()
  end

  test "normalize_display/1 keeps explicit values" do
    assert {:ok, [width: 1024, height: 600, framebuffer: "/tmp/fb1"]} =
             LovyanGFX.Options.normalize_display(
               width: 1024,
               height: 600,
               framebuffer: "/tmp/fb1"
             )
  end

  test "normalize_display/1 rejects non-keyword input" do
    assert {:error, :invalid_options} = LovyanGFX.Options.normalize_display(%{width: 800})
    assert {:error, :invalid_options} = LovyanGFX.Options.normalize_display([800, 480])
  end

  test "normalize_display/1 validates option types" do
    assert {:error, {:invalid_option, :width, -1}} =
             LovyanGFX.Options.normalize_display(width: -1)

    assert {:error, {:invalid_option, :height, "480"}} =
             LovyanGFX.Options.normalize_display(height: "480")

    assert {:error, {:invalid_option, :framebuffer, ""}} =
             LovyanGFX.Options.normalize_display(framebuffer: "")
  end
end
