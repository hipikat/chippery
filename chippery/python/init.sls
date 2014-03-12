#
# Python setup with system-wide pyenv, virtualenv, virtualenvwrapper, etc.
##########################################################################

{% set chippery = pillar['chippery'] %}

#include:
#  - chippery.sysenv


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
{% endfor %}

# Users' ~/.profile files should `source /etc/profile.d/virtualenvwrapper.sh`.
# TODO: work out how to best arrange this whole insane shell startup mess.
/etc/profile.d/virtualenvwrapper.sh:
  file.managed:
    - user: root
    - group: root
    - mode: 444 
    - source: salt://chippery/python/templates/virtualenvwrapper-init.sh
    - template: jinja
    - context:
        venv_path: {{ venv_path }}
        proj_path: {{ proj_path }}
    - require:
      - pip: chp|system_python_virtualenvwrapper

#/etc/chippery.d/virtualenvwrapper.sh:
#  file.managed:
#    - template: jinja
#    - user: root
#    - group: root
#    - mode: 444 
#    - source: salt://chippery/python/templates/virtualenvwrapper-env.sh
#    - context:
#        venv_path: {{ venv_path }}
#        proj_path: {{ proj_path }}
#    - require:
#      - pip: chp|system_python_virtualenvwrapper
#      - file: /etc/chippery.d


# Simple Python version management: https://github.com/yyuu/pyenv
https://github.com/yyuu/pyenv.git:
  git.latest:
    - target: /usr/local/pyenv

#/usr/local/bin/pyenv:
#  file.symlink:
#    - name: 
#    - target: /usr/local/pyenv/libexec/pyenv

/usr/local/bin/pyenv:
  file.managed:
    - user: root
    - group: root
    - mode: 554
    - source: salt://chippery/python/templates/pyenv.sh

#/etc/profile.d/pyenv.sh:
#  file.managed:
#    - user: root
#    - group: root
#    - mode: 444
#    - source: salt://chippery/python/templates/pyenv-init.sh

#/etc/chippery.d/pyenv.sh:
#  file.managed:
#    - user: root
#    - group: root
#    - mode: 444
#    - source: salt://chippery/python/templates/pyenv-env.sh

eval "$(pyenv init -)":
  cmd.run:
    - env:
        PYENV_ROOT: /usr/local/pyenv
    - watch:
      - git: https://github.com/yyuu/pyenv.git

#/usr/local/bin/pyenv:
#  file.managed:
#    - mode: 755
#    - require:
#      - file: chp|python|symlink=pyenv
