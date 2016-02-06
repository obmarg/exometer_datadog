# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Disable lagers error logging, as it seems to crash when faced with a map.
config :lager, error_logger_redirect: false
