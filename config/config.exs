import Config

env_config_path = Path.join(__DIR__, "#{config_env()}.exs")

if File.exists?(env_config_path) do
  import_config "#{config_env()}.exs"
end
