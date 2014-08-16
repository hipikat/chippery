#!stateconf -o yaml . jinja
#
# Nginx setup
#########################################################

{% set chippery = pillar['chippery'] %}
{% set settings = chippery.get('settings', {}) %}
{% set nginx = settings.get('nginx', {}) %}


.Nginx system package:
  pkg.installed:
    - name: nginx

  file.managed:
    - name: /etc/nginx/nginx.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 444
    - source: salt://chippery/nginx/templates/nginx.conf
    - require:
      - pkg: .Nginx system package

# The default server, configured in nginx.conf, just closes any incoming
# connections without a response (return 444). Project dicts should contain
# a list of virtual_hosts, which should each contain a list of locations.
.Remove Nginx's 'default' server:
  file.absent:
    - name: /etc/nginx/sites-enabled/default

# chippery.nginx.status should be one of 'running', 'disabled' or 'manual'
{% set nginx_status = nginx.get('status', 'running') %}
# Only affect Nginx's state if chippery.nginx.managed is absent or True
{% if nginx.get('managed', true) and nginx_status != 'manual' %}
.Ensure Nginx is {{ nginx_status }}:

  {% if nginx_status == 'running' %}
  service.running:
    - name: nginx
    - enable: True
    {% if nginx.get('reload', false) %}
    # Just reload configuration (instead of restarting) when triggered.
    - reload: True
    {% endif %}
    - watch:
      - file: .Nginx system package

  {% else %}
  service.dead:
    - name: nginx
  {% endif %}

{% endif %}
