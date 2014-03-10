#
# Nginx setup
#########################################################

{% set chippery = pillar['chippery'] %}

# TODO: Allow configurable installation from source; steal from nginx-formula.
chp|install_nginx:
  pkg.installed:
    - name: nginx

# Main Nginx configuration file
/etc/nginx/nginx.conf:
  file.managed:
    - template: jinja
    - user: root
    - group: root
    - mode: 444
    - source: salt://chippery/nginx/templates/nginx.conf
    - require:
      - pkg: chp|install_nginx

# Provide a default Nginx server response, for when hostnames don't
# match any configured servers - especially useful for development boxes
# with multiple projects being served, where Nginx will otherwise make
# the first loaded server the default. Example (in your pillar):
# chippery:
#  nginx_default:
#    directives:
#      - return 444 
{% if 'nginx_default' not in chippery %}
/etc/nginx/sites-enabled/default:
  file:
    - absent
{% else %}
/etc/nginx/sites-available/default:
  file.managed:
    - source: salt://chippery/nginx/templates/default.conf
    - mode: 444 
    - template: jinja
    - context:
        directives: {{ chippery['nginx_default']['directives'] }}

/etc/nginx/sites-enabled/default:
  file.symlink:
    - target: /etc/nginx/sites-available/default
{% endif %}

# We use the plain 'nginx' name to increase the chance of a conflict
# in case any other states are planning to manage nginx. Higher-level
# formulas (e.g. chippery.wsgi_stack or chippery.php_stack) should use
# a watch_in statement on nginx.
nginx:
  service:
    - running
    - enable: True
    - reload: True
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/sites-enabled/default
