defmodule LovyanGFX.BufferedFramebufferTargetTest do
  use ExUnit.Case, async: false

  @moduletag :target

  @opts [
    width: 854,
    height: 480,
    framebuffer: "/dev/fb0",
    framebuffer_mode: :buffered_rgb565,
    swap_bytes: true
  ]

  test "renders and presents a buffered RGB565 frame" do
    assert File.exists?(@opts[:framebuffer])
    assert LovyanGFX.start(@opts) in [:ok, :already_started]
    assert LovyanGFX.width() == 854
    assert LovyanGFX.height() == 480

    rgb565_2x2 = <<0x00, 0xF8, 0xE0, 0x07, 0x1F, 0x00, 0xFF, 0xFF>>

    assert :ok =
             LovyanGFX.render([
               {:fill_screen, :black},
               {:fill_rect, 16, 16, 120, 64, :red},
               {:draw_round_rect, 160, 16, 160, 64, 12, :green},
               {:draw_circle, 380, 48, 30, :blue},
               {:draw_line, 440, 16, 560, 80, :white},
               {:set_text_datum, :top_left},
               {:set_text_color, :white},
               {:draw_string, "LovyanGFX 日本語", 16, 110, :japan_gothic_24},
               {:push_rgb565, 16, 160, 2, 2, rgb565_2x2},
               {:create_sprite, :badge, 48, 48, 16},
               {:target, :badge},
               {:fill_screen, :blue},
               {:fill_circle, 24, 24, 18, :white},
               {:target, :screen},
               {:push_sprite, :badge, 600, 16},
               {:push_rotate_zoom, :badge, 720, 48, 30, 1.2, 1.2},
               {:delete_sprite, :badge}
             ])
  end

  test "preserves normalized RGB565 colors at the native boundary" do
    assert LovyanGFX.start(@opts) in [:ok, :already_started]
    assert :ok = LovyanGFX.render([{:fill_screen, {:rgb888, 0x00182F}}])

    assert {:ok, framebuffer} = File.open(@opts[:framebuffer], [:read, :binary, :raw])
    assert <<0xC5, 0x00>> = IO.binread(framebuffer, 2)
    File.close(framebuffer)
  end

  test "MovingIcons can stop and restart on the initialized buffered display" do
    assert LovyanGFX.Examples.MovingIcons.start(@opts) in [:ok, :already_started]
    Process.sleep(100)
    assert :ok = LovyanGFX.Examples.MovingIcons.stop()

    assert :ok = LovyanGFX.Examples.MovingIcons.start(@opts)
    Process.sleep(100)
    assert :ok = LovyanGFX.Examples.MovingIcons.stop()
  end
end
