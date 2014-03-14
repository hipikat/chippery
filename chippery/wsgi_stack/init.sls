#
# Standardised setup WSGI project stacks. Initially just
# getting Django projects working, then generalising…
# Tested on Ubuntu 13.04 (Raring) and 13.10 (Saucy).
##########################################################

### Django projects
### Basic stack: Nginx + uWSGI + Virtualenv + Supervisord

{% set chippery = pillar['chippery'] %}
{% set venv_path = chippery.get('virtualenv_path', '/opt/venv') %}
{% set proj_path = chippery.get('project_path', '/opt/proj') %}


# System Python and web server setup
include:
  - chippery.python
  - chippery.nginx


# Include system packages used by the WSGI stack.
# The lib[ssl|pcre3]-dev packages are for uWSGI routing support,
# Supervisor is used to manage uWSGI processes, and
# apache2-utils is requied to generate htpasswd files.
{% set wsgi_sys_pkgs = (
  'libssl-dev', 'libpcre3-dev',
  'supervisor',
  'apache2-utils',
) %}
chp|wsgi|system_packages:
  pkg.installed:
    - pkgs:
      {% for sys_pkg in wsgi_sys_pkgs %}
        - {{ sys_pkg }}
      {% endfor %}


# Standard uWSGI paramters passed to Nginx config files
/etc/nginx/uwsgi_params:
  file.managed:
    - source: salt://chippery/templates/uwsgi_params
    - mode: 444


### The projects
{% for deploy_name, project in chippery['wsgi_projects'].items() %}


# Functional modules listed in a project's 'include' list
{% if 'include' in project %}
{% set includes = project['include'] %}

{% if 'pillow' in includes %}
chp|project={{ deploy_name }}|include=pillow:
  pkg.installed:
    - pkgs:
      - python-dev
      - python-setuptools
{% endif %}

{% if 'postgresql' in includes %}
chp|project={{ deploy_name }}|include=postgresql:
  pkg.installed:
    - pkgs:
      - postgresql-9.1
      - python-psycopg2
      - libpq-dev
{% endif %}

{% endif %}   # End 'include' in project


# Project source (git) checkout
chp|project={{ deploy_name }}:
  git.latest:
    - name: {{ project.git_url }}
    - target: {{ proj_path }}/{{ deploy_name }}
    {% if 'git_rev' in project %}
    - rev: {{ project['git_rev'] }}
    {% endif %}

{{ proj_path }}/{{ deploy_name }}:
  file.directory:
    - user: www-data
    - group: www-data
    - recurse:
      - user
      - group


# Python executable
pyenv install {{ project['python_version'] }}:
  cmd.run:
    - unless: test -e /usr/local/pyenv/versions/{{ project['python_version'] }}
    # The 'creates' argument becomes available in Salt 2014.1.0...
    #- creates: /usr/local/pyenv/versions/{{ project['python_version'] }}


# Project virtual environment
{{ venv_path }}/{{ deploy_name }}:
  virtualenv.managed:
    - python: /usr/local/pyenv/versions/{{ project['python_version'] }}/bin/python
    {% if 'python_requirements' in project %}
    - requirements: {{ proj_path }}/{{ deploy_name }}/{{ project.python_requirements }}
    {% endif %}
  require:
    - pip.installed: chp|system_python_virtualenv


# Virtualenvwrapper association between project & virtualenv
{{ venv_path }}/{{ deploy_name }}/.project:
  file.managed:
    - mode: 444
    - contents: {{ proj_path }}/{{ deploy_name }}


# Databases and database users
{% if 'postgresql' in project.get('include', []) %}

chp|project={{ deploy_name }}|db=postgresql:
{% for db_obj in ('database', 'user'): %}
  postgres_{{ db_obj }}:
    - name: {{ deploy_name }}
    - present
    - require:
      - pkg: chp|project={{ deploy_name }}|include=postgresql
{% endfor %}

{% endif %}   # End if 'postgresql' in project['include']


# Envdir (flat files whose names/contents form environment keys/values)
{% if 'envdir' in project and 'env' in project: %}
{% for key, value in project['env'].iteritems(): %}
{{ proj_path }}/{{ deploy_name }}/{{ project['envdir'] }}/{{ key }}:
  file.managed:
    - mode: 444
    - contents: {{ value }}
{% endfor %}
{% endif %}


# Python paths
{% if 'pythonpaths' in project %}
# TODO: This currently just assumes python2.7. Fix it.
{{ venv_path }}/{{ deploy_name }}/lib/python2.7/site-packages/_django_project_paths.pth:
  file.managed:
    - source: salt://projects/templates/pythonpath_config.pth
    - mode: 444
    - template: jinja
    - context:
        base_dir: {{ proj_path }}/{{ deploy_name }}
        paths: {{ project['pythonpaths'] }}
{% endif %}








{% endfor %}  # End for deploy_name, project in wsgi_mash
