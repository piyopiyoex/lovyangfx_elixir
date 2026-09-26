defmodule LovyanGFXTest do
  use ExUnit.Case, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    previous_backend = Application.get_env(:lovyangfx_elixir, :backend)
    Application.put_env(:lovyangfx_elixir, :backend, LovyanGFX.MockBackend)

    on_exit(fn ->
      if previous_backend do
        Application.put_env(:lovyangfx_elixir, :backend, previous_backend)
      else
        Application.delete_env(:lovyangfx_elixir, :backend)
      end
    end)

    :ok
  end

  test "start/1 delegates normalized default options to the backend" do
    expect(LovyanGFX.MockBackend, :start, fn opts ->
      assert opts == [width: 800, height: 480, framebuffer: "/dev/fb0"]
      :ok
    end)

    assert :ok = LovyanGFX.start()
  end

  test "start/1 delegates explicit options to the backend" do
    expect(LovyanGFX.MockBackend, :start, fn opts ->
      assert opts == [width: 320, height: 240, framebuffer: "/tmp/fb1"]
      :already_started
    end)

    assert :already_started =
             LovyanGFX.start(width: 320, height: 240, framebuffer: "/tmp/fb1")
  end

  test "start/1 rejects invalid options before reaching the backend" do
    assert {:error, :invalid_options} = LovyanGFX.start(%{width: 800})
    assert {:error, {:invalid_option, :width, 0}} = LovyanGFX.start(width: 0)
    assert {:error, {:invalid_option, :framebuffer, ""}} = LovyanGFX.start(framebuffer: "")
  end

  test "render/1 normalizes commands before delegating to the backend" do
    expect(LovyanGFX.MockBackend, :render, fn commands ->
      assert commands == [{:fill_screen, 0xFFFF}, {:draw_pixel, 1, 2, 0xF800}]
      :ok
    end)

    assert :ok =
             LovyanGFX.render([
               {:fill_screen, :white},
               {:draw_pixel, 1, 2, :red}
             ])
  end

  test "render/1 returns validation errors without reaching the backend" do
    assert {:error, :commands_must_be_a_list} = LovyanGFX.render(:invalid)

    assert {:error, {:unknown_color, :not_a_color}} =
             LovyanGFX.render([{:fill_screen, :not_a_color}])
  end


  test "render/1 preserves image file commands for backend handling" do
    path = Path.join(System.tmp_dir!(), "lovyangfx_render_test.png")

    expect(LovyanGFX.MockBackend, :render, fn commands ->
      assert commands == [{:draw_png_file, path, 12, 34}]
      :ok
    end)

    assert :ok = LovyanGFX.render([{:draw_png_file, path, 12, 34}])
  end

  test "MovingIcons.stop/0 delegates when the backend supports stop" do
    expect(LovyanGFX.MockBackend, :moving_icons_stop, fn -> :ok end)

    assert :ok = LovyanGFX.Examples.MovingIcons.stop()
  end

  test "timings/0 delegates to the moving icons backend" do
    expect(LovyanGFX.MockBackend, :moving_icons_timings, fn -> 12.5 end)

    assert 12.5 = LovyanGFX.timings()
  end

  test "set_status/1 delegates to the moving icons backend" do
    expect(LovyanGFX.MockBackend, :moving_icons_set_status, fn "CPU OK" -> :ok end)

    assert :ok = LovyanGFX.set_status("CPU OK")
  end

  test "set_touch/1 delegates to the moving icons backend" do
    expect(LovyanGFX.MockBackend, :moving_icons_set_touch, fn "Touch ON" -> :ok end)

    assert :ok = LovyanGFX.set_touch("Touch ON")
  end
end
