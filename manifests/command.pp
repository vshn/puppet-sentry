# == Define: sentry::command
#
# This define executes sentry commands.
#
# === Parameters
#
# [*command*]
#   The command to execute including any arguments.
#
# [*refreshonly*]
#   Whether to execute only when an event is received, defaults to `false`.
#
define sentry::command(
  $command     = $title,
  $refreshonly = false,
) {
  include sentry
  $config_path = $sentry::version ? {
    /8/     => "${sentry::path}/",
    default => "${sentry::path}/sentry.conf.py"
  }

  validate_string($command)
  validate_bool($refreshonly)

  exec { "sentry_command_${title}":
    command     => join([
      "${sentry::path}/virtualenv/bin/sentry",
      "--config=${config_path}",
      $command
    ], ' '),
    user        => $sentry::owner,
    refreshonly => $refreshonly,
  }
}
