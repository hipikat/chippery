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
{% set project_user = settings.get('project_user', 'root') %}
{% set project_group = settings.get('project_group', project_user) %}
{% if project_group == 'root' %}
  {% set venv_dir_mode = '755' %}
{% else %}
  {% set venv_dir_mode = '775' %}
{% endif %}


####
# Ensure the existence of required user groups
####
# Before 'includes' because Pyenv etc. get their group set to 'project_group'
# TODO: Under 'Install projects', add groups for individual projects
#
# Think: SHOULD we create users and groups?? Shouldn't we?
#
#{% if project_user != 'root' %}
#.Default project user '{{ project_user }}' for Chippery projects:
#  user.present:
#    - name: {{ settings['project_group'] }}
#    - createhome: False
#{% endif %}

#{% if project_group != 'root' %}
#.Default project group '{{ project_group }}' for Chippery projects:
#  group.present:
#    - name: {{ settings['project_group'] }}
#{% endif %}


####
# System components
####
# This is where Jinja2 really starts to show its weaknesses. This whole
# thing would probably be much nicer if it was converted to Mako.
{% set includes = {
  'chippery.null': True,
  'chippery.nginx': False,
  'chippery.python.pyenv': False,
  'chippery.python.virtualenv': False,
} %}

{% if settings.get('nginx', {}).get('managed', True) %}
  {% if includes.update({'chippery.nginx': True}) %}{% endif %}
{% endif %}

{% for deploy_name, project in projects.iteritems() %}

  # Test for Virtualenv requirement
  {% if 'python_src' in project or 'python_requirements' in project or
        'python_libs' in project or 'python_packages' in project %}
        {% if includes.update({'chippery.python.virtualenv': True}) %}{% endif %}
  {% endif %}

  # Test for non-system-Python requirement (which will install Pyenv)
  {% if project.get('python_version', 'system') != 'system' %}
    {% if includes.update({'chippery.python.pyenv': True}) %}{% endif %}
  {% endif %}

{% endfor %}

# Include system components
include:
      - chippery.null
  {% for state, include in includes.items() %}
    {% if include %}
      - {{ state }}
    {% endif %}
  {% endfor %}



####
# Install projects
####
{% for deploy_name, project in projects.items() %}

  # Generic settings
  {% set project_path = settings.get('project_path', '/opt') ~ '/' ~ deploy_name %}

  # Python settings
  {% set venv_path = settings.get('virtualenv_path', '/opt/.virtualenvs') ~ '/' ~ deploy_name %}
  {% set python_version = project.get('python_version', 'system') %}
  {% if 'python_src' or 'python_requirements' or 'python_libs' or 'python_packages' in project %}
    {% set require_virtualenv = True %}
  {% endif %}


  ####
  # Project source code
  ####
  {% if 'source' in project %}
    {% set source = project['source'] %}
    {% if source is not mapping %}
      {% set source = {'url': source} %}
    {% endif %}

    {% if 'deploy_key' in source %}
.Deployment key for '{{ deploy_name }}':
  file.managed:
    - name: /var/local/{{ deploy_name }}/deploy_key
    - source: {{ source['deploy_key'] }}
    - user: {{ project_user }}
    - group: {{ project_group }}
    - mode: 600
    - makedirs: True
    {% endif %}

.Ownership of /var/local/{{ deploy_name }} after creating deploy_key:
  file.directory:
    - name: /var/local/{{ deploy_name }}
    - user: {{ project_user }}
    - group: {{ project_group }}

    {% if 'url' in source %}
.Git-checkout source for project '{{ deploy_name }}':
  git.latest:
    - name: {{ project['source']['url'] }}
      {% if 'rev' in source %}
    - rev: {{ source['rev'] }}
      {% endif %}
    - target: {{ project_path }}
    - runas: {{ project_user }}
      {% if 'remote_name' in source %}
    - remote_name: {{ source['remote_name'] }}
      {% endif %}
      {% if 'deploy_key' in source %}
    - identity: /var/local/{{ deploy_name }}/deploy_key
      {% endif %}
    {% endif %}

  {% endif %}{# if 'source' in project #}


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
  #
  # Note: We install the virtualenv without requirements, then install libraries,
  # then install from a requirements file if one is given. If we were to use the
  # `requirements` argument to `virtualenv.managed`, dependancies may be
  # automatically installed when they should actually be satisfied by libraries.
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

.Configuration (etc) directory for virtualenv '{{ deploy_name }}':
  file.directory:
    - name: {{ venv_path }}/etc
    - user: {{ project_user }}
    - group: {{ project_group }}
    - mode: 775

.Symlink to site-packages in virtualenv '{{ deploy_name }}':
  cmd.run:
    - name: ln -sf `{{ venv_path }}/bin/python -c 'import distutils; print({# -#}
      {#- #} distutils.sysconfig.get_python_lib())'` {{ venv_path }}/site-packages
    - creates: {{ venv_path }}/site-packages

.Log directory in virtualenv '{{ deploy_name }}':
  file.directory:
    - name: {{ venv_path }}/var/log
    - makedirs: True

    # Virtualenvwrapper association between project & virtualenv
    {% if 'source' in project %}
.Associate '{{ deploy_name }}' source with its virtualenv:
  file.managed:
    - name: {{ venv_path }}/.project
    - mode: 444
    - contents: {{ project_path }}
    {% endif %}

    ####
    # App server (a uWSGI process managed by Supervisor)
    ####

    {% if 'wsgi_module' in project: %}

      # Virtualenv-local uWSGI install
.uWSGI Python package in virtualenv for project '{{ deploy_name }}':
  pip.installed:
    - name: uWSGI
    - bin_env: {{ venv_path }}/bin/pip

      # Supervisor uWSGI task
.Supervisor task for running uWSGI for project '{{ deploy_name }}':
  file.managed:
    - name: /etc/supervisor/conf.d/{{ deploy_name }}.conf:
    - source: salt://chippery/templates/supervisor-uwsgi.conf
    - mode: 444
    - template: jinja
    - context:
        program_name: {{ deploy_name }}
        uwsgi_bin: {{ venv_path }}/bin/uwsgi
        uwsgi_ini: {{ venv_path }}/etc/uwsgi.ini

.Update Supervisor process list; configuration for project '{{ deploy_name }}' changed:
  module.wait:
    - name: supervisord.update
    - watch:
      - file: /etc/supervisor/conf.d/{{ deploy_name }}.conf

.uWSGI configuration file for project '{{ deploy_name }}':
  file.managed:
    - name: {{ venv_path }}/etc/uwsgi.ini:
    - source: salt://chippery/wsgi_stack/templates/uwsgi-master.ini
    - mode: 444
    - makedirs: True
    - template: jinja
    - context:
        # Easier to do basic auth at the Nginx level? Much of a muchness?
        #basicauth: {{ project.get('http_basic_auth', false) }}
        #realm: {{ deploy_name }}
        #htpasswd_file: {{ venv_path }}/etc/{{ deploy_name }}.htpasswd
        socket: {{ venv_path }}/var/uwsgi.sock
        wsgi_module: {{ project['wsgi_module'] }}
        virtualenv: {{ venv_path }}
        uwsgi_log: /opt/var/{{ deploy_name }}/var/log/uwsgi.log

    # Enable/disable the Supervisord/uWSGI job
    {% set wsgi_enabled = project.get('wsgi_process', 'running') %}
    {% if wsgi_enabled == 'running' %}

.Ensure uWSGI process for project '{{ deploy_name }}' is running:
  supervisord.running:
    - name: {{ deploy_name }}

    {% elif wsgi_enabled = False %}

.Ensure uWSGI process for project '{{ deploy_name }}' is disabled:
  supervisord.dead:
    - name: {{ deploy_name }}

    {% endif %}


  ####
  # Web server (Nginx)
  ####

.Nginx configuration for project '{{ deploy_name }}':
  file.managed:
    - name: /etc/nginx/sites-available/{{ deploy_name }}.conf
    - source: salt://chippery/templates/nginx-uwsgi-proxy.conf
    - mode: 444
    - template: jinja
    - context:
        project_name: {{ deploy_name }}
        project_root: {{ project_path }}
        upstream_server: unix://{{ venv_path }}/var/uwsgi.sock
        port: {{ project.get('port', 80) }}
        servers: {{ project['servers'] }}
        http_basic_auth: {{ project.get('http_basic_auth', False) }}


  {% endif %}   # End if require_virtualenv



  ####
  # Databases
  ####

  {% for db_name, db_info in project.get('databases', {}).iteritems() %}

    ### PostgreSQL
    {% if db_info.get('type') == 'postgres' %}
      {% set db_user = db_info.get('owner', db_name) %}

.Database user '{{ db_user }}' for project '{{ deploy_name }}':
  postgres_user.present:
    - name: {{ db_user }}
    - password: {{ db_info['password'] }}
    {% if db_user in chippery.get('sysadmins', []) %}
    - createdb: true
    {% endif %}

.Postgresql database '{{ db_name }}' for project '{{ deploy_name }}':
  postgres_database.present:
    - name: {{ db_name }}
    - owner: {{ db_user }}

    {% endif %}   # End if db_info.get('type') == 'postgres'
  {% endfor %}    # End for db_name, db_info in project['databases']

  ####
  # Web server
  ###


{% endfor %}{# deploy_name, project in projects #}

