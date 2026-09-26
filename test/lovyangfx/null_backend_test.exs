defmodule LovyanGFX.NullBackendTest do
  use ExUnit.Case, async: false

  setup do
    LovyanGFX.NullBackend.reset()
    previous_echo = Application.get_env(:lovyangfx_elixir, :null_backend_echo)
    Application.put_env(:lovyangfx_elixir, :null_backend_echo, false)

    on_exit(fn ->
      LovyanGFX.NullBackend.reset()

      if is_nil(previous_echo) do
        Application.delete_env(:lovyangfx_elixir, :null_backend_echo)
      else
        Application.put_env(:lovyangfx_elixir, :null_backend_echo, previous_echo)
      end
    end)

    :ok
  end

  test "start/1 records display options" do
    assert :ok =
             LovyanGFX.NullBackend.start(
               width: 800,
               height: 480,
               framebuffer: "/dev/fb0"
             )

    assert LovyanGFX.NullBackend.width() == 800
    assert LovyanGFX.NullBackend.height() == 480
    assert LovyanGFX.NullBackend.rotation() == 0

    assert %{
             started?: true,
             options: [width: 800, height: 480, framebuffer: "/dev/fb0"]
           } = LovyanGFX.NullBackend.state()
  end

  test "render/1 records normalized commands" do
    assert :ok = LovyanGFX.NullBackend.render([{:fill_screen, 0x0000}])
    assert :ok = LovyanGFX.NullBackend.render([{:draw_pixel, 1, 2, 0xFFFF}])

    assert %{
             commands: [
               {:fill_screen, 0x0000},
               {:draw_pixel, 1, 2, 0xFFFF}
             ]
           } = LovyanGFX.NullBackend.state()
  end

  test "moving icons calls are recorded" do
    assert :ok = LovyanGFX.NullBackend.moving_icons_start(width: 800, height: 480)
    assert :ok = LovyanGFX.NullBackend.moving_icons_set_status("CPU OK")
    assert :ok = LovyanGFX.NullBackend.moving_icons_set_touch("Touch ON")

    assert %{
             moving_icons_started?: true,
             moving_icons_options: [width: 800, height: 480],
             moving_icons_status: "CPU OK",
             moving_icons_touch: "Touch ON"
           } = LovyanGFX.NullBackend.state()

    assert %{backend: :null, started?: true} = LovyanGFX.NullBackend.moving_icons_timings()

    assert :ok = LovyanGFX.NullBackend.moving_icons_stop()
    assert %{moving_icons_started?: false} = LovyanGFX.NullBackend.state()
  end

  test "public API can use the null backend" do
    previous_backend = Application.get_env(:lovyangfx_elixir, :backend)
    Application.put_env(:lovyangfx_elixir, :backend, LovyanGFX.NullBackend)

    try do
      assert :ok = LovyanGFX.start(width: 320, height: 240, framebuffer: "/tmp/fb0")

      assert :ok =
               LovyanGFX.render([
                 {:fill_screen, :black},
                 {:draw_pixel, 1, 2, :white}
               ])

      assert LovyanGFX.width() == 320
      assert LovyanGFX.height() == 240

      assert %{
               started?: true,
               options: [width: 320, height: 240, framebuffer: "/tmp/fb0"],
               commands: [{:fill_screen, 0x0000}, {:draw_pixel, 1, 2, 0xFFFF}]
             } = LovyanGFX.NullBackend.state()
    after
      if previous_backend do
        Application.put_env(:lovyangfx_elixir, :backend, previous_backend)
      else
        Application.delete_env(:lovyangfx_elixir, :backend)
      end
    end
  end
end
