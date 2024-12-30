{ pkgs, lib, config, inputs, ... }:

{
  packages = [ pkgs.jq pkgs.git pkgs.postgresql ];

  env = {
    NANOMDM_API_KEY = "f*N8qsbUfr.HRYn7JV2_2fwHgbiWZge";
    NANOMDM_DB_URL = "postgres://postgres@localhost:5432/monimentor-mdm?sslmode=disable";
  };

  scripts = {
    nanomdm.exec = ''
      ./nanomdm-darwin-arm64 $@
    '';

    init_db.exec = ''
      psql -h localhost -U postgres -d monimentor-mdm -f ./storage/pgsql/schema.sql
    '';

    serve.exec = ''
      nanomdm -ca ca.pem -api $NANOMDM_API_KEY -storage pgsql -storage-dsn $NANOMDM_DB_URL
    '';
  };

  languages = {
    go = {
      enable = true;
    };
  };


}
