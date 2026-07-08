defmodule LovyanGFX.Backend do
  @moduledoc false

  @callback start(keyword()) :: :ok | :already_started | {:error, term()}
  @callback render(list()) :: :ok | {:error, term()}
  @callback width() :: integer()
  @callback height() :: integer()
  @callback rotation() :: integer()
  @callback moving_icons_start(keyword()) :: :ok | :already_started | {:error, term()}
  @callback moving_icons_timings() :: term()
  @callback moving_icons_set_status(String.t()) :: :ok | {:error, term()}
  @callback moving_icons_set_touch(String.t()) :: :ok | {:error, term()}

  def impl do
    Application.get_env(:lovyangfx_elixir, :backend, LovyanGFX.NativeBackend)
  end
end
