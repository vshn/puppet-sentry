# == Class: sentry::service
#
# This class is meant to be called from sentry.
# It ensures the service is running.
#
class sentry::service
{

  $version     = $sentry::version
  $config_path = $sentry::version ? {
    /8/     => $sentry::path,
    default => "${sentry::path}/sentry.conf.py"
  }

  $command = join([
    "${sentry::path}/virtualenv/bin/sentry",
    "--config=${config_path}"
  ], ' ')
  if $::running_on_systemd {
    include ::systemd

    systemd::resources::unit {
      default:
        ensure     => 'present',
        user       => $sentry::owner,
        workingdir => $sentry::path;
      'sentry-cron':
        execstart => "${command} run cron";
      'sentry-http':
        execstart => "${command} run web";
      'sentry-worker':
        execstart => "${command} run worker";
    }

    service {
      default:
        ensure => 'running',
        enable => true;
      'sentry-cron':;
      'sentry-http':;
      'sentry-worker':;
    }

  } else {


    Supervisord::Program {
      ensure          => present,
      directory       => $sentry::path,
      user            => $sentry::owner,
      autostart       => true,
      redirect_stderr => true,
      notify          => Supervisord::Supervisorctl['sentry_reload'],
    }


    if $version =~ /^8\./ {
      supervisord::program {
        'sentry-http':
          command => "${command} run web",
        ;
        'sentry-worker':
          command => "${command} run worker",
        ;
        'sentry-beat':
          command => "${command} run cron"
      }
    }
    else {
      supervisord::program {
        'sentry-http':
          command => "${command} start http",
        ;
        'sentry-worker':
          command => "${command} celery worker -B",
        ;
      }
    }


    if $sentry::service_restart {

      supervisord::supervisorctl { 'sentry_reload':
        command     => 'reload',
        refreshonly => true,
      }
    }
  }
}
