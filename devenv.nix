{ pkgs, lib, config, inputs, ... }:

{
  packages = [ pkgs.jq pkgs.git pkgs.postgresql pkgs.step-ca pkgs.step-cli ];

  env = {
    NANOMDM_API_KEY = "f*N8qsbUfr.HRYn7JV2_2fwHgbiWZge";
    NANOMDM_DB_USER = "postgres";
    NANOMDM_DB_HOST = "localhost";
    NANOMDM_DB_PORT = "5432";
    NANOMDM_DB_DATABASE = "monimentor-mdm";
    NANOMDM_WEBHOOK_URL = "http://my.localhost.com/internal/webhooks/mdm";
  };

  scripts = {
    nanomdm.exec = ''
      ./nanomdm-darwin-arm64 $@
    '';

    init_db.exec = ''
      psql -h localhost -U postgres -d monimentor-mdm -f ./storage/pgsql/schema.sql
    '';

    add_push.exec = ''
      cat mdm-certificates/PushCertificate.pem mdm-certificates/PushCertificatePrivateKey.key | \
      curl -T - -u nanomdm:$NANOMDM_API_KEY 'http://127.0.0.1:9000/v1/pushcert'
    '';

    push.exec = ''
      curl -u nanomdm:$NANOMDM_API_KEY "http://127.0.0.1:9000/v1/push/$1"
    '';

    enqueue.exec = ''
      curl -T - -u nanomdm:$NANOMDM_API_KEY "http://127.0.0.1:9000/v1/enqueue/$1"
    '';

    serve.exec = ''
      set -ex
      while ! nc -z $NANOMDM_DB_HOST $NANOMDM_DB_PORT; do
        sleep 0.1
      done
      NANOMDM_DB_URL="postgres://$NANOMDM_DB_USER@$NANOMDM_DB_HOST:$NANOMDM_DB_PORT/$NANOMDM_DB_DATABASE?sslmode=disable";
      echo "$NANOMDM_DB_URL"
      psql -U $NANOMDM_DB_USER -h $NANOMDM_DB_HOST -p $NANOMDM_DB_PORT $NANOMDM_DB_DATABASE -c 'select count(*) from devices' || init_db;
      nanomdm -ca ca.pem -api $NANOMDM_API_KEY -storage pgsql -storage-dsn $NANOMDM_DB_URL -webhook-url $NANOMDM_WEBHOOK_URL -debug
    '';
  };

  languages = {
    go = {
      enable = true;
    };
    python = {
      enable = true;
    };
  };


}
