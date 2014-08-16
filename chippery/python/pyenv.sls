#!stateconf -o yaml . jinja
#
# Set up components required for basic Python development
########################################################################

{% set chippery = pillar.get('chippery', {}) %}
{% set settings = chippery.get('settings', {}) %}

{% set venv_user = settings.get('project_user', 'root') %}
{% set venv_group = settings.get('project_group', venv_user) %}


# Install Pyenv, and its requirements, to manage Python versions
.System packages required for Pyenv to build new Python binaries:
  pkg.installed:
    - pkgs:
      - build-essential
      - libssl-dev
      - zlib1g-dev
      - libbz2-dev
      - libreadline-dev
      - libsqlite3-dev

.Install Pyenv:
  git.latest:
    - name: https://github.com/yyuu/pyenv.git
    - target: /usr/local/pyenv
  file.directory:
    - name: /usr/local/pyenv
    - user: {{ venv_user }}
    - group: {{ venv_group }}
    - recurse:
      - user
      - group
    - require:
      - git: .Install Pyenv

.Pyenv environment setup and execution script:
  file.managed:
    - name: /usr/local/bin/pyenv
    - user: root
    - group: root
    - mode: 555
    - source: salt://chippery/python/templates/pyenv.sh

.Initialise Pyenv 'shims' and 'versions' directories:
  cmd.run:
    - name: eval "$(pyenv init -)"
    - env:
        PYENV_ROOT: /usr/local/pyenv
    - creates: /usr/local/pyenv/shims

.Install Pyenv-Virtualenv:
  git.latest:
    - name: https://github.com/yyuu/pyenv-virtualenv.git
    - target: /usr/local/pyenv/plugins/pyenv-virtualenv

.Install Pyenv-Virtualenvwrapper:
  git.latest:
    - name: https://github.com/yyuu/pyenv-virtualenvwrapper.git
    - target: /usr/local/pyenv/plugins/pyenv-virtualenvwrapper
