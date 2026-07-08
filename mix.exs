defmodule LovyanGFX.MixProject do
  use Mix.Project

  @app :lovyangfx_elixir
  @version "0.2.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  def cli do
    [
      preferred_targets: [run: :host, test: :host]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.8", runtime: false},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "Elixir/NIF wrapper for LovyanGFX framebuffer rendering."
  end

  defp package do
    [
      files: [
        "lib",
        "config",
        "c_src",
        "priv/.gitkeep",
        "Makefile",
        "LICENSE",
        "README.md",
        "mix.exs",
        ".formatter.exs",
        "scripts/update_lovyangfx"
      ],
      licenses: ["MIT"],
      links: %{}
    ]
  end
end
