#!stateconf -o yaml . jinja
#
# Machine-wide settings
########################################################################

{% set chippery = pillar.get('chippery', {}) %}
{% set settings = chippery.get('settings', {}) %}


# Set a default UMASK for the machine
{% if 'default_umask' in settings %}
.Set default UMASK on the minion:
  file.replace:
    - name: /etc/login.defs
    - pattern: ^UMASK\s+[\dx]+
    - repl: UMASK\t\t{{ settings['default_umask'] }}
    - flags: ['IGNORECASE']
    - backup: False
{% endif %}
