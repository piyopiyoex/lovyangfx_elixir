defmodule LovyanGFX.NullBackend do
  @moduledoc """
  Non-rendering backend for local development and IEx exploration.

  This backend implements the same contract as `LovyanGFX.NativeBackend`, but it
  does not load the NIF or touch a framebuffer. It records the latest calls so
  developers can inspect the command flow from local IEx.
  """

  @behaviour LovyanGFX.Backend

  @state_key :null_backend_state

  @empty_state %{
    started?: false,
    options: nil,
    commands: [],
    moving_icons_started?: false,
    moving_icons_options: nil,
    moving_icons_status: nil,
    moving_icons_touch: nil
  }

  @impl true
  def start(opts) do
    update_state(%{@empty_state | started?: true, options: opts})
    maybe_echo(:start, opts)
    :ok
  end

  @impl true
  def render(commands) do
    update_state(fn state ->
      state
      |> Map.update!(:commands, &(&1 ++ commands))
    end)

    maybe_echo(:render, commands)
    :ok
  end

  @impl true
  def width do
    state()
    |> Map.get(:options)
    |> case do
      nil -> 0
      opts -> Keyword.get(opts, :width, 0)
    end
  end

  @impl true
  def height do
    state()
    |> Map.get(:options)
    |> case do
      nil -> 0
      opts -> Keyword.get(opts, :height, 0)
    end
  end

  @impl true
  def rotation, do: 0

  @impl true
  def moving_icons_start(opts) do
    update_state(fn state ->
      state
      |> Map.put(:moving_icons_started?, true)
      |> Map.put(:moving_icons_options, opts)
    end)

    maybe_echo(:moving_icons_start, opts)
    :ok
  end

  @impl true
  def moving_icons_timings do
    %{
      backend: :null,
      fps: 0,
      frame_ms: 0,
      started?: Map.get(state(), :moving_icons_started?, false)
    }
  end

  @impl true
  def moving_icons_set_status(text) do
    update_state(&Map.put(&1, :moving_icons_status, text))
    maybe_echo(:moving_icons_set_status, text)
    :ok
  end

  @impl true
  def moving_icons_set_touch(text) do
    update_state(&Map.put(&1, :moving_icons_touch, text))
    maybe_echo(:moving_icons_set_touch, text)
    :ok
  end

  @doc "Return the recorded null-backend state. Useful from local IEx."
  def state do
    Application.get_env(:lovyangfx_elixir, @state_key, @empty_state)
  end

  @doc "Clear the recorded null-backend state. Useful between local IEx trials."
  def reset do
    Application.put_env(:lovyangfx_elixir, @state_key, @empty_state)
    :ok
  end

  defp update_state(new_state) when is_map(new_state) do
    Application.put_env(:lovyangfx_elixir, @state_key, new_state)
  end

  defp update_state(fun) when is_function(fun, 1) do
    state()
    |> fun.()
    |> update_state()
  end

  defp maybe_echo(label, value) do
    if Application.get_env(:lovyangfx_elixir, :null_backend_echo, false) do
      IO.inspect(value, label: "LovyanGFX.NullBackend.#{label}")
    end
  end
end
