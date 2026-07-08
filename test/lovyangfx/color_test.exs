defmodule LovyanGFX.ColorTest do
  use ExUnit.Case, async: true

  test "normalize/1 accepts named colors" do
    assert {:ok, 0xF800} = LovyanGFX.Color.normalize(:red)
    assert {:ok, 0x07FF} = LovyanGFX.Color.normalize(:tft_cyan)
  end

  test "normalize/1 converts rgb tuples" do
    assert {:ok, 0xF800} = LovyanGFX.Color.normalize({:rgb, 255, 0, 0})
    assert {:ok, 0x07E0} = LovyanGFX.Color.normalize({:rgb888, 0x00FF00})
  end

  test "normalize/1 accepts rgb565 integers" do
    assert {:ok, 0x1234} = LovyanGFX.Color.normalize({:rgb565, 0x1234})
    assert {:ok, 0xABCD} = LovyanGFX.Color.normalize(0xABCD)
  end

  test "normalize/1 rejects invalid values" do
    assert {:error, {:unknown_color, :infrared}} = LovyanGFX.Color.normalize(:infrared)
    assert {:error, {:invalid_rgb_channel, 300}} = LovyanGFX.Color.normalize({:rgb, 300, 0, 0})

    assert {:error, {:invalid_color, {:rgb565, 0x1_0000}}} =
             LovyanGFX.Color.normalize({:rgb565, 0x1_0000})
  end
end
