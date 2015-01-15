require 'spec_helper_acceptance'

describe 'sentry' do
  context 'with default parameters' do
    let(:pp) {"
      class { 'sentry':
        # We set these next two to avoid warnings about insecure defaults
        password_hash => 'pbkdf2_sha256$20000$Isa9Kri0hOob$oqPbWfPjb8N8CEBX63UVINAhT5rmtCryOz3F3SE53mA=',
        secret_key    => 'k0gAJI2BDyUq/24iEdUmVkyTvHz8h5mbdC1Sj7IIR103Gcg1AaHbhw==',
        extra_config  => [
          # The default dummy tsdb returns bogus errors during testing
          'SENTRY_TSDB = \\'sentry.tsdb.inmemory.InMemoryTSDB\\'',
          # The default smtp email backend needs extra configuration, so switch to locmem
          'EMAIL_BACKEND = \\'django.core.mail.backends.locmem.EmailBackend\\'',
        ]
      }
    "}

    it 'applies with no errors' do
      apply_manifest(pp, :catch_failures => true)
    end

    it 'is idempotent' do
      apply_manifest(pp, :catch_changes => true)
    end

    describe service('supervisord') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command('supervisorctl status sentry-http') do
      its(:stdout) { is_expected.to match(/RUNNING/) }
      its(:stderr) { is_expected.to be_empty }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe port(9000) do
      it {
        sleep 10  # wait for daemon to fully start
        is_expected.to be_listening
      }
    end

    describe command('supervisorctl status sentry-worker') do
      its(:stdout) { is_expected.to match(/RUNNING/) }
      its(:stderr) { is_expected.to be_empty }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command("#{SENTRY_COMMAND} dumpdata sentry.user") do
      its(:stdout) { is_expected.to match(/"pk": 1/) }
      its(:stdout) { is_expected.to match(/"password": "pbkdf2_sha256\$20000\$Isa9Kri0hOob\$oqPbWfPjb8N8CEBX63UVINAhT5rmtCryOz3F3SE53mA="/) }
      its(:stdout) { is_expected.to match(/"email": "root@localhost"/) }
      its(:stdout) { is_expected.to match(/"username": "admin"/) }
      its(:stderr) { is_expected.to be_empty }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command("#{SENTRY_COMMAND} validate") do
      its(:stdout) { is_expected.to match(/0 errors found/) }
      its(:stderr) { is_expected.to be_empty }
      its(:exit_status) { is_expected.to eq 0 }
    end

    describe command("#{SENTRY_COMMAND} send_fake_data --num=3") do
      its(:stdout) { is_expected.to match(/3 requests serviced/) }
      its(:stderr) { is_expected.to be_empty }
      its(:exit_status) { is_expected.to eq 0 }
    end
  end
end
