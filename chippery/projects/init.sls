#!stateconf -o yaml . jinja
#
# Install projects from pillar.chippery.projects 
########################################################################


{% set chippery = pillar['chippery'] %}
{% set settings = chippery.get('settings', {}) %}
{% set projects = chippery['projects'] %}

####
# Global settings
####

# Global Python settings
{% set venv_user = settings.get('project_user', 'root') %}
{% set venv_group = settings.get('project_group', venv_user) %}
{% if venv_group == 'root' %}
  {% set venv_dir_mode = '755' %}
{% else %}
  {% set venv_dir_mode = '775' %}
{% endif %}


####
# System components
####

# Test for system components to include
{% set include_virtualenv = False %}
{% set include_pyenv = False %}
{% for project in projects %}

  # Test for Virtualenv requirement
  {% if 'python_src' or 'python_requirements' or 'python_libs' or 'python_packages' in project %}
    {% set include_virtualenv = True %}
  {% endif %}

  # Test for non-system-Python requirement (which will install Pyenv)
  {% if 'python_version' in project and project['python_version'] != 'system' %}
    {% set include_pyenv = True %}
  {% endif %}

{% endfor %}


# Include system components
include:
    - chippery.null

  # Install, run and manage Nginx unless we're told not to
  {% if settings.get('nginx', {}).get('managed', true) %}
    - chippery.nginx
  {% endif %}

  # Include other system components with more complex tests (above)
  {% if include_virtualenv %}
    - chippery.python.virtualenv
  {% endif %}
  {% if include_pyenv %}
    - chippery.python.pyenv
  {% endif %}


####
# Install projects
####
{% for deploy_name, project in chippery['projects'].items() %}

  # Generic settings
  {% set proj_path = settings.get('project_path', '/opt') ~ '/' ~ deploy_name %}

  # Python settings
  {% set venv_path = settings.get('virtualenv_path', '/opt/.virtualenvs') ~ '/' ~ deploy_name %}
  {% set python_version = project.get('python_version', 'system') %}
  {% if 'python_src' or 'python_requirements' or 'python_libs' or 'python_packages' in project %}
    {% set require_virtualenv = True %}
  {% endif %}

  ####
  # Python-based projects
  ####

  # Build a non-system version of Python (if required)
  {% if python_version != 'system' %}
.Build Python {{ python_version }} for {{ deploy_name }}:
  cmd.run:
    - name: pyenv install {{ python_version }}
    - creates: /usr/local/pyenv/versions/{{ python_version }}
  {% endif %}


  {% if require_virtualenv %}

    # Install a Python Virtualenv for the project
.Virtualenv for {{ deploy_name }}:
  virtualenv.managed:
    - name: {{ venv_path }}
    {% if python_version != 'system' %}
    - python: /usr/local/pyenv/versions/{{ python_version }}/bin/python
    {% endif %}

    # Install Python packages specified in the pillar
    {% for python_package in project.get('python_packages', []) %}
.Install Python package {{ python_package }} into virtualenv for {{ deploy_name }}:
  pip.installed:
    - name: {{ python_package }}
    - bin_env: {{ venv_path }}
    - use_wheel: True
    {% endfor %}

  {% endif %}{# require_virtualenv #}


{% endfor %}
