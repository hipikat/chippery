#
# Standardised setup WSGI project stacks. Initially just
# getting Django projects working, then generalising…
# Tested on Ubuntu 13.04 (Raring) and 13.10 (Saucy).
##########################################################

### Django projects
### Basic stack: Nginx + uWSGI + Virtualenv + Supervisord

{% set chippery = pillar['chippery'] %}


### Implicit core-system includes
{% for deploy_name, project in chippery['wsgi_projects'].items() %}

{% for db_name, db_info in project.get('databases', {}).items() %}

{% if db_info.get('type') == 'postgres' %}
  {% set include_postgres = true %}
{% endif %}

{% endfor %}
{% endfor %}

include:
  # System-Python and web server setup
  - chippery.python
  - chippery.nginx
  {% if include_postgres is defined %}
  - chippery.postgres
  {% endif %}

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

{% set venv_path = chippery.get('virtualenv_path', '/opt/venv') ~ '/' ~ deploy_name %}
{% set proj_path = chippery.get('project_path', '/opt/proj') ~ '/' ~ deploy_name %}
{% set proj_owner = project.get('owner', 'root') %}
{% set proj_group = project.get('group', 'www-data') %}


{% if 'system_packages' in project %}
chp|project={{ deploy_name }}|sys_pkgs:
  pkg.installed:
    - pkgs:
      {% for pkg in project['system_packages'] %}
      - {{ pkg }}
      {% endfor %}
{% endif %}

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

{% endif %}   # End 'include' in project


# Project source (git) checkout
chp|project={{ deploy_name }}:
  git.latest:
    - name: {{ project.git_url }}
    - target: {{ proj_path }}
    {% if 'git_rev' in project %}
    - rev: {{ project['git_rev'] }}
    {% endif %}

{{ proj_path }}:
  file.directory:
    - user: {{ proj_owner }}
    - group: {{ proj_group }}
    - recurse:
      - user
      - group


# Python executable
{% set py_version = project.get('python_version', 'system') %}
chp|project={{ deploy_name }}|pyenv install {{ py_version }}:
  cmd.run:
    - name: pyenv install {{ py_version }}
    - unless: test -e /usr/local/pyenv/versions/{{ project['python_version'] }}
    # The 'creates' argument becomes available in Salt 2014.1.0…
    #- creates: /usr/local/pyenv/versions/{{ project['python_version'] }}


# Project virtual environment
#
# NB: We install the virtualenv without requirements, then install libraries,
# then install from a requirements file if one is given. If we were to use the
# `requirements` argument to `virtualenv.managed`, dependancies may be
# automatically installed when they should actually be satisfied by libraries.
{{ venv_path }}:
  virtualenv.managed:
    - python: /usr/local/pyenv/versions/{{ project['python_version'] }}/bin/python
    - require:
      - pip: chp|system_python_virtualenv
  file.directory:
    - user: {{ proj_owner }}
    - group: {{ proj_group }}
    - recurse:
      - user
      - group
    - require:
      - virtualenv: {{ venv_path }}

# Virtualenv-centric directories…
# TODO: Make sure ownership and permissions are all good
{{ venv_path }}/etc:
  file.directory:
    - mode: 755 
    - user: {{ proj_owner }}
    - group: {{ proj_group }}

# Shortcut symlink to a virtualenv's site-packages directory
# Creates, for example, `/opt/venv/fooenv/site-pkgs`, which would link
# to /opt/venv/fooenv/lib/python2.7/site-packages, adjusting for
# whatever Python executable the virtualenv is created with.
chp|project={{ deploy_name }}|state=ln -sf {{ venv_path }}/site-pkgs:
  cmd.run:
    - name: ln -sf `{{ venv_path }}/bin/python -c 'import distutils; print({# -#}
      {#- #} distutils.sysconfig.get_python_lib())'` {{ venv_path }}/site-pkgs
    - require:
      - virtualenv: {{ venv_path }}
    - onlyif: test ! -h {{ venv_path }}/site-pkgs

chp|project={{ deploy_name }}|file.exists={{ venv_path }}/site-pkgs:
  file.exists:
    - name: {{ venv_path }}/site-pkgs


{{ venv_path }}/var/log:
  file.directory:
    - makedirs: True

{{ venv_path }}/var:
  file.directory:
    - user: www-data
    - mode: 770 
    - recurse:
      - user
      - mode


# Install Virtualenvwrapper in Virtualenvs…
chp|project={{ deploy_name }}|virtualenvwrapper:
  pip.installed:
    - name: virtualenvwrapper
    - bin_env: {{ venv_path }}

# Virtualenvwrapper association between project & virtualenv
{{ venv_path }}/.project:
  file.managed:
    - mode: 444
    - contents: {{ proj_path }}


# Databases and database users
{% for db_name, db_info in project.get('databases', {}).iteritems() %}

{% if db_info.get('type') == 'postgres' %}

{% set db_user = db_info.get('owner', db_name) %}
chp|project={{ deploy_name }}|db_user={{ db_user }}:
  postgres_user.present:
    - name: {{ db_user }}
    # TODO: Get this from the pillar :)
    - password: 'insecure'
    {% if db_user in chippery.get('sysadmins', []) %}
    - createdb: true
    {% endif %}
    - require:
      - pkg: chp|init=postgres

chp|project={{ deploy_name }}|db={{ db_name }}:
  postgres_database.present:
    - name: {{ db_name }}
    - owner: {{ db_user }}
    - require:
      - postgres_user: chp|project={{ deploy_name }}|db_user={{ db_user }}

{% endif %}   # End if db_info['type'] == 'postgres'

{% endfor %}  # End for db_name, db_info in project['databases']


# Envdir (flat files whose names/contents form environment keys/values)
{% if 'envdir' in project and 'env' in project: %}
{{ proj_path }}/{{ project['envdir'] }}:
  file.directory:
    - mode: 755
    - user: {{ proj_owner }}
    - group: {{ proj_group }}

{% for key, value in project['env'].iteritems(): %}
{{ proj_path }}/{{ project['envdir'] }}/{{ key }}:
  file.managed:
    - mode: 444
    - contents: {{ value }}
{% endfor %}
{% endif %}


# Python paths
{% if 'python_paths' in project %}
{{ venv_path }}/site-pkgs/chippery_paths.pth:
  file.managed:
    - source: salt://chippery/python/templates/pythonpath_config.pth
    - mode: 444
    - template: jinja
    - context:
        base_dir: {{ proj_path }}
        paths: {{ project['python_paths'] }}
    - require:
      - file: chp|project={{ deploy_name }}|file.exists={{ venv_path }}/site-pkgs
{% endif %}


# Additional libraries required by the project
{% if 'lib_root' in project %}
{{ proj_path }}/{{ project['lib_root'] }}:
  file.directory:
    - makedirs: True

{% if 'libs' in project %}

{% set default_lib_type = project.get('default_lib_type', 'git') %}

{% for lib_deploy_name, lib_details in project['libs'].iteritems() %}

{% set lib_path = proj_path ~ '/' ~ project['lib_root'] ~ '/' ~ lib_deploy_name %}
{% if lib_details is string %}
  {% set lib_details = { 'url': lib_details } %}
{% endif %}

# Clone this git library…
{% if lib_details.get('type', default_lib_type) == 'git' %}

chp|project={{ deploy_name }}|lib={{ lib_deploy_name }}:
  git.latest:
    - name: {{ lib_details['url'] }}
    - target: {{ lib_path }}
    {% if 'rev' in lib_details %}
    - rev: {{ lib_details['rev'] }}
    {% endif %}
  file.directory:
    - name: {{ lib_path }}
    - user: {{ proj_owner }}
    - group: {{ proj_group }}
    - recurse:
      - user
      - group

{% endif %}   # End if lib_details.get('type', default_lib_type) == 'git'

{% if 'pip-install' in lib_details and lib_details['pip-install'] %}
{% if lib_details['pip-install'] is mapping %}
  {% set pip_args = lib_details['pip-install'] %}
{% else %}
  {% set pip_args = {} %}
{% endif %}

chp|project={{ deploy_name }}|lib={{ lib_deploy_name }}|state=pip:
  pip.installed:
    - name: {{ lib_deploy_name }}
    - bin_env: {{ venv_path }}
    {% if 'editable' in pip_args %}
    - editable: file://{{ lib_path }}
    {% endif %}

{% endif %}   # End if 'pip-install' in lib_details and lib_details['pip-install']

{% endfor %}  # End for lib_deploy_name, lib_details in project['libs'].iteritems()

{% endif %}   # End if 'libs' in project

{% endif %}   # End if 'lib_dir' in project


# Install virtualenv requirements, once all libs are installed
{% if 'python_requirements' in project %}
chp|project={{ deploy_name }}|state=pip_requirements:
  pip.installed:
    - bin_env: {{ venv_path }}
    - requirements: {{ proj_path }}/{{ project['python_requirements'] }}
    - require:
      - virtualenv: {{ venv_path }}
      {% for lib_deploy_name, lib_details in project.get('libs', []).iteritems() %}
      {% if 'pip-install' in lib_details and lib_details['pip-install'] %}
      - pip: chp|project={{ deploy_name }}|lib={{ lib_deploy_name }}|state=pip
      {% endif %}
      {% endfor %}
{% endif %}


# Post-install hooks
{% if 'post_install' in project %}
{% for hook_name, hook in project['post_install'].iteritems(): %}

chp|project={{ deploy_name }}|post_install={{ hook_name }}:
  cmd.run:
    - name: {{ hook['run']|replace('%proj%', proj_path)|replace('%venv%', venv_path) }}
    - cwd: {{ proj_path }}
    {% if 'onlyif' in hook %}
    - onlyif: {{ hook['onlyif']|replace('%proj%', proj_path)|replace('%venv%', venv_path) }}
    {% endif %}
    {% if 'user' in hook %}
    - user: {{ hook['user'] }}
    {% endif %}

{% endfor %}
{% endif %}


# uWSGI setup
{% if 'wsgi_module' in project: %}

# Virtualenv-local uWSGI install
chp|project={{ deploy_name }}|pip=uwsgi:
  pip.installed:
    - name: uWSGI
    - bin_env: {{ venv_path }}/bin/pip

# Supervisor uWSGI task
/etc/supervisor/conf.d/{{ deploy_name }}.conf:
  file.managed:
    - source: salt://chippery/wsgi_stack/templates/supervisor-uwsgi.conf
    - mode: 444
    - template: jinja
    - context:
        program_name: {{ deploy_name }}
        uwsgi_bin: {{ venv_path }}/bin/uwsgi
        uwsgi_ini: {{ venv_path }}/etc/uwsgi.ini
    - require:
      - pip: chp|project={{ deploy_name }}|pip=uwsgi

chp|project={{ deploy_name }}|update=supervisor:
  module.wait:
    - name: supervisord.update
    - watch:
      - file: /etc/supervisor/conf.d/{{ deploy_name }}.conf

{{ venv_path }}/etc/uwsgi.ini:
  file.managed:
    - source: salt://chippery/wsgi_stack/templates/uwsgi-master.ini
    - mode: 444
    - makedirs: True
    - template: jinja
    - context:
        # TODO: Easier to do this at the Nginx level? Much of a muchness?
        #basicauth: {{ project.get('http_basic_auth', false) }}
        #realm: {{ deploy_name }}
        #htpasswd_file: {{ venv_path }}/etc/{{ deploy_name }}.htpasswd
        socket: {{ venv_path }}/var/uwsgi.sock
        wsgi_module: {{ project['wsgi_module'] }}
        virtualenv: {{ venv_path }}
        uwsgi_log: /opt/var/{{ deploy_name }}/var/log/uwsgi.log

# Enable/disable the Supervisord/uWSGI job
chp|project={{ deploy_name }}|state=supervisor:
  {% if project.get('wsgi_enabled', True) %}
  supervisord.running:
  {% else %}
  supervisord.dead:
  {% endif %}
    - name: {{ deploy_name }}

# Nginx hook-up
/etc/nginx/sites-available/{{ deploy_name }}.conf:
  file.managed:
    - source: salt://chippery/wsgi_stack/templates/nginx-uwsgi-proxy.conf
    - mode: 444
    - template: jinja
    - context:
        project_name: {{ deploy_name }}
        project_root: {{ proj_path }}
        upstream_server: unix://{{ venv_path }}/var/uwsgi.sock
        port: {{ project['port'] }}
        servers: {{ project['servers'] }}
        http_basic_auth: {{ project.get('http_basic_auth', false) }}

# Nginx running-state and state of the project config in Nginx's sites-enabled/
chp|project={{ deploy_name }}|state=nginx:
{% if project.get('site_enabled') or project.get('wsgi_enabled', true) %}
# If site_enabled is explicitly true or wsgi_enabled isn't false, ensure that
# Nginx is running and the site's config is linked into sites-enabled/.
  service.running:
    - name: nginx
    - reload: True
    - watch:
      - file: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
  file.symlink:
    - name: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
    - target: /etc/nginx/sites-available/{{ deploy_name }}.conf
{% elif not project.get('site_enabled', true) %}
# Otherwise, if site_enabled is explicitly false, ensure that the site's
# config file is NOT linked into sites-enabled/ (and don't bother Nginx).
  file.absent:
    - name: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
{% endif %}

# Nginx-level HTTP Basic Authentication
{% if project.get('http_basic_auth', false) %}

{% for user in project.get('admins', []) %}
{% if pillar.get('users', {}).get(user, {}).get('htpasswd') %}
chp|project={{ deploy_name }}|http_basic_auth={{ user }}:
  file.append:
    - name: {{ venv_path }}/etc/{{ deploy_name }}.htpasswd
    - text: {{ user }}:{{ pillar['users'][user]['htpasswd'] }}
    - makedirs: true
{% endif %}
{% endfor %}

{{ venv_path }}/etc/{{ deploy_name }}.htpasswd:
  file.managed:
    - owner: www-data
    - mode: 400

{% endif %}   # End if project['http_basic_auth']


{% endif %}   # End if 'wsgi_module' in project


{% endfor %}  # End for deploy_name, project in wsgi_projects
