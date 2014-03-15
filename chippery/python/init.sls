#
# Python setup with system-wide pyenv, virtualenv, virtualenvwrapper, etc.
########################################################################

{% set chippery = pillar['chippery'] %}


# System-Python package manager (pip) and libraries required to build
# new Python versions with Pyenv
chp|system_python_pip:
  pkg.installed:
    - pkgs:
      - python-pip
      - build-essential
      - libssl-dev
      - zlib1g-dev
      - libbz2-dev
      - libreadline-dev
      - libsqlite3-dev

# System-Python packages for Virtualenv
{% for py_pkg in (
  'virtualenv', 'virtualenvwrapper',
) %}
chp|system_python_{{ py_pkg }}:
  pip.installed:
    - name: {{ py_pkg }}
    - require:
      - pkg: chp|system_python_pip
{% endfor %}


# Virtualenv and virtualenvwrapper.
{% set venv_path = chippery.get('virtualenv_path', '/opt/venv') %}
{% set proj_path = chippery.get('project_path', '/opt/proj') %}

{% for path in (venv_path, proj_path) %}
{{ path }}:
  file.directory:
    - user: root
    - group: root
    - mode: 775
    - makedirs: True
{% endfor %}


# Use virtualenvwrapper as a tool for system-wide shared environments…
/usr/local/bin/virtualenvwrapper.sh:
  file.blockreplace:
    - content: |
        export WORKON_HOME={{ venv_path }}
        export VIRTUALENVWRAPPER_HOOK_DIR=/usr/local/virtualenvwrapper/hooks
        export PROJECT_HOME={{ proj_path }}
    - prepend_if_not_found: True
    - backup: False

/usr/local/virtualenvwrapper/hooks:
  file.directory:
    - user: root
    - group: root
    - mode: 775
    - makedirs: True

# This command creates the inital Virtualenvwrapper hooks
source /usr/local/bin/virtualenvwrapper.sh:
  cmd.run:
    - watch:
      - file: /usr/local/bin/virtualenvwrapper.sh


# Simple Python version management: https://github.com/yyuu/pyenv
https://github.com/yyuu/pyenv.git:
  git.latest:
    - target: /usr/local/pyenv

/usr/local/bin/pyenv:
  file.managed:
    - user: root
    - group: root
    - mode: 555
    - source: salt://chippery/python/templates/pyenv.sh

# This command initialises Pyenv `shims` and `versions` directories
eval "$(pyenv init -)":
  cmd.run:
    - env:
        PYENV_ROOT: /usr/local/pyenv
    - watch:
      - git: https://github.com/yyuu/pyenv.git
