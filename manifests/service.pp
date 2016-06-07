# == Class: sentry::service
#
# This class is meant to be called from sentry.
# It ensures the service is running.
#
class sentry::service
{

  $version     = $sentry::version
  $config_path = $sentry::version ? {
    /8/     => "${sentry::path}/",
    default => "${sentry::path}/sentry.conf.py"
  }

  $command = join([
    "${sentry::path}/virtualenv/bin/sentry",
    "--config=${config_path}"
  ], ' ')

  Supervisord::Program {
    ensure          => present,
    directory       => $sentry::path,
    user            => $sentry::owner,
    autostart       => true,
    redirect_stderr => true,
  }

  anchor { 'sentry::service::begin': } ->

  if $version >= '8' {
    supervisord::program {
      'sentry-http':
        command => "${command} run web",
      ;
      'sentry-worker':
        command => "${command} run worker",
      ;
      'sentry-beat':
        command => "${command} run cron"
    } ->
  }
  else {
    supervisord::program {
      'sentry-http':
        command => "${command} start http",
      ;
      'sentry-worker':
        command => "${command} celery worker -B",
      ;
    } ->
  }

  anchor { 'sentry::service::end': }

  if $sentry::service_restart {
    Anchor['sentry::service::begin'] ~>

    supervisord::supervisorctl { 'sentry_reload':
      command     => 'reload',
      refreshonly => true,
    }
  }
}
