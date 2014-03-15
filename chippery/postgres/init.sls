#
# Postgresql core includes

chp|init=postgres:
  pkg.installed:
    - pkgs:
      - postgresql-9.1
      - python-psycopg2
      - libpq-dev
