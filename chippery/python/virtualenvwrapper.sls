#!stateconf -o yaml . jinja
#
# Set up components required for basic Python development
########################################################################

{% set chippery = pillar.get('chippery', {}) %}
{% set settings = chippery.get('settings', {}) %}

{% set venv_user = settings.get('project_user', 'root') %}
{% set venv_group = settings.get('project_group', venv_user) %}
{% if venv_group == 'root' %}
  {% set venv_dir_mode = '755' %}
{% else %}
  {% set venv_dir_mode = '775' %}
{% endif %}


# Install virtualenvwrapper, for Python-developer convenience
.System-Python Virtualenvwrapper package:
  pkg.installed:
    - name: python-pip
  pip.installed:
    - name: virtualenvwrapper
    - require:
      - pkg: .System-Python Virtualenvwrapper package


# Users should `source /usr/local/bin/set_chippery_env.sh` if they want
# to use Chippery's shared, global Virtualenvwrapper settings.
{% set venv_path = settings.get('virtualenv_path', '/opt/.virtualenvs') %}
{% set proj_path = settings.get('project_path', '/opt') %}

.Virtualenvwrapper virtualenv directory permissions:
  file.directory:
    - name: {{ venv_path }}
    - user: {{ venv_user }}
    - group: {{ venv_group }}
    - dir_mode: {{ venv_dir_mode }}

.Virtualenvwrapper project directory permissions:
  file.directory:
    - name: {{ proj_path }}
    - user: {{ venv_user }}
    - group: {{ venv_group }}
    - dir_mode: {{ venv_dir_mode }}

.Virtualenvwrapper configuration:
  file.blockreplace:
    - name: /usr/local/bin/set_chippery_env.sh
    - marker_start: '# <{{ sls }}::Virtualenvwrapper configuration>'
    - marker_end: '# </{{ sls }}::Virtualenvwrapper configuration>'
    - content: |
        #
        # Shared environment settings for Virtualenvwrapper
        export WORKON_HOME={{ venv_path }}
        export VIRTUALENVWRAPPER_HOOK_DIR=/usr/local/virtualenvwrapper/hooks
        export PROJECT_HOME={{ proj_path }}
    - append_if_not_found: True
    - backup: False

.Virtualenvwrapper hooks directory:
  file.directory:
    - name: /usr/local/virtualenvwrapper/hooks
    - user: root
    - group: root
    - mode: 775
    - makedirs: True

.Create default Virtualenvwrapper hooks:
  cmd.run:
    - name: . /usr/local/bin/virtualenvwrapper.sh
    - shell: /bin/bash
    - env:
        - WORKON_HOME: {{ venv_path }}
        - VIRTUALENVWRAPPER_HOOK_DIR: /usr/local/virtualenvwrapper/hooks
        - PROJECT_HOME: {{ proj_path }} 
    - creates: /usr/local/virtualenvwrapper/hooks
