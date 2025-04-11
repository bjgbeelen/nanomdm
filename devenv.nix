{ pkgs, lib, config, inputs, ... }:

{
  packages = (with pkgs; [ jq git postgresql step-ca step-cli 
    (google-cloud-sdk.withExtraComponents([google-cloud-sdk.components.gke-gcloud-auth-plugin]))
  ]);

  env = {
    NANOMDM_API_KEY = "f*N8qsbUfr.HRYn7JV2_2fwHgbiWZge";
    NANOMDM_DB_USER = "postgres";
    NANOMDM_DB_HOST = "localhost";
    NANOMDM_DB_PORT = "5432";
    NANOMDM_DB_DATABASE = "monimentor-mdm";
    NANOMDM_WEBHOOK_URL = "http://my.localhost.com/internal/webhooks/mdm";
  };

  scripts = {
    get-project-id.exec = ''
      gcloud projects list --filter "name:$1" --format="value(project_id)"
    '';

    database.exec = ''
      env=$1
      port=''${2:-5432}
      if [[ $env = 'prd' ]]; then
        export POSTGRES_PWD="op://private/Postgres Monimentor MDM/$env"
        password=$(op run --no-masking -- printenv POSTGRES_PWD)
        APP__DATABASE__USER="mdm:$password"
      fi
      echo "$APP__DATABASE__USER@localhost:$port/monimentor-mdm"
    '';

    short-sha.exec = ''
      git rev-parse --short HEAD
    '';

    repo-name.exec = ''
      echo $(basename $(pwd))
    '';

    image-name.exec = ''
      ops_project_id=$(get-project-id monimentor-ops)
      echo europe-west4-docker.pkg.dev/$ops_project_id/docker/$(repo-name)
    '';

    full-image-name.exec = ''
      app=$1
      echo "$(image-name $app):$(short-sha)"
    '';


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
        sleep 1
      done
      NANOMDM_DB_URL="postgres://$NANOMDM_DB_USER@$NANOMDM_DB_HOST:$NANOMDM_DB_PORT/$NANOMDM_DB_DATABASE?sslmode=disable";
      echo "$NANOMDM_DB_URL"
      psql -U $NANOMDM_DB_USER -h $NANOMDM_DB_HOST -p $NANOMDM_DB_PORT $NANOMDM_DB_DATABASE -c 'select count(*) from devices' || init_db;
      nanomdm -ca ca.pem -api $NANOMDM_API_KEY -storage pgsql -storage-dsn $NANOMDM_DB_URL -webhook-url $NANOMDM_WEBHOOK_URL -debug
    '';

    sqlproxy.exec = ''
      env=$1
      port=''${2:-5440}
      echo "Establishing a sql connection to $env. Keep this running"
      gcloud compute ssh "bastion-$env" --zone europe-west4-b --project $(get-project-id monimentor-main-$env) \
       -- -L $port:localhost:5432 -N -f
    '';

    build.exec = ''
      set -e
      env=$1
      GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=$(short-sha)" -o nanomdm-linux-amd64 ./cmd/nanomdm
      gcloud auth configure-docker europe-west4-docker.pkg.dev
      full_image_name=$(full-image-name)
      docker buildx build --platform linux/amd64 --build-arg GIT_SHA=$(short-sha) \
       -t $full_image_name --load .
      for additional_tag in "$@"
      do
        docker tag $full_image_name "$(image-name):$additional_tag"
      done
      docker push -a $(image-name)
    '';

    sync-schema.exec = ''
      env=$1
      port=5446
      sqlproxy $env $port
      export ALEMBIC_CONNECTION=$(database $env $port)
      echo "Syncing database schema"
      psql "postgresql://$ALEMBIC_CONNECTION" -f ./storage/pgsql/schema.sql
      kill $(lsof -ti :$port)
      echo "Closed sql proxy to monimentor-mdm $env"
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
