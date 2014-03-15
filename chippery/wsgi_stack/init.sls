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
    # The 'creates' argument becomes available in Salt 2014.1.0…
    #- creates: /usr/local/pyenv/versions/{{ project['python_version'] }}


# Project virtual environment
{{ venv_path }}/{{ deploy_name }}:
  virtualenv.managed:
    - python: /usr/local/pyenv/versions/{{ project['python_version'] }}/bin/python
    {% if 'python_requirements' in project %}
    - requirements: {{ proj_path }}/{{ deploy_name }}/{{ project.python_requirements }}
    {% endif %}
    - require:
      - pip: chp|system_python_virtualenv

# Virtualenv-centric directories…
# TODO: Make sure ownership and permissions are all good?
{{ venv_path }}/{{ deploy_name }}/etc:
  file.directory:
    - mode: 755 

# Shortcut symlink to a virtualenv's site-packages directory
chp|project={{ deploy_name }}|state=link_site-pkgs:
  cmd.wait:
    - name: ln -sf `{{ venv_path }}/{{ deploy_name }}/bin/python -c 'import distutils; print({# -#}
      {#- #} distutils.sysconfig.get_python_lib())'` {{ venv_path }}/{{ deploy_name }}/site-pkgs
    - watch:
      - virtualenv: {{ venv_path }}/{{ deploy_name }}

{{ venv_path }}/{{ deploy_name }}/var/log:
  file.directory:
    - makedirs: True

{{ venv_path }}/{{ deploy_name }}/var:
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
    - bin_env: {{ venv_path }}/{{ deploy_name }}

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
{% if 'python_paths' in project %}
{{ venv_path }}/{{ deploy_name }}/site-pkgs/chippery_paths.pth:
  file.managed:
    - source: salt://chippery/python/templates/pythonpath_config.pth
    - mode: 444
    - template: jinja
    - context:
        base_dir: {{ proj_path }}/{{ deploy_name }}
        paths: {{ project['python_paths'] }}
    - require:
      - virtualenv: {{ venv_path }}/{{ deploy_name }}
{% endif %}


# Additional libraries required by the project
{% if 'lib_dir' in project %}
{{ proj_path }}/{{ deploy_name }}/{{ project['lib_dir'] }}:
  file.directory:
    - makedirs: True

{% if 'git_libs' in project %}
{% for dest, repo_details in project['git_libs'].iteritems(): %}
{% if repo_details is string %}
  {% set repo = { 'url': repo_details } %}
{% else %}
  {% set repo = repo_details %}
{% endif %}
chp|project={{ deploy_name }}|git_lib={{ dest }}:
  git.latest:
    - name: {{ repo['url'] }}
    - target: {{ proj_path }}/{{ deploy_name }}/{{ project['lib_dir'] }}/{{ dest }}
{% endfor %}
{% endif %}

{% endif %}   # End if 'lib_dir' in project


# Post-install hooks
{% if 'post_install' in project %}
{% for hook_name, hook in project['post_install'].iteritems(): %}
{% set cwd = proj_path ~ '/'  ~ deploy_name %}

chp|project={{ deploy_name }}|post_install={{ hook_name }}:
  cmd.run:
    - name: {{ hook['run'] }}
    - cwd: {{ cwd }}
    {% if 'onlyif' in hook %}
    - onlyif: {{ hook['onlyif']|replace('%cwd%', cwd) }}
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
    - bin_env: {{ venv_path }}/{{ deploy_name }}/bin/pip

# Supervisor uWSGI task
/etc/supervisor/conf.d/{{ deploy_name }}.conf:
  file.managed:
    - source: salt://chippery/wsgi_stack/templates/supervisor-uwsgi.conf
    - mode: 444
    - template: jinja
    - context:
        program_name: {{ deploy_name }}
        uwsgi_bin: {{ venv_path }}/{{ deploy_name }}/bin/uwsgi
        uwsgi_ini: {{ venv_path }}/{{ deploy_name }}/etc/uwsgi.ini
    - require:
      - pip: chp|project={{ deploy_name }}|pip=uwsgi

chp|project={{ deploy_name }}|update=supervisor:
  module.wait:
    - name: supervisord.update
    - watch:
      - file: /etc/supervisor/conf.d/{{ deploy_name }}.conf

{{ venv_path }}/{{ deploy_name }}/etc/uwsgi.ini:
  file.managed:
    - source: salt://chippery/wsgi_stack/templates/uwsgi-master.ini
    - mode: 444
    - makedirs: True
    - template: jinja
    - context:
        # TODO: Easier to do this at the Nginx level? Much of a muchness?
        #basicauth: {{ project.get('http_basic_auth', false) }}
        #realm: {{ deploy_name }}
        #htpasswd_file: {{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd
        socket: {{ venv_path }}/{{ deploy_name }}/var/uwsgi.sock
        wsgi_module: {{ project['wsgi_module'] }}
        virtualenv: {{ venv_path }}/{{ deploy_name }}
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
        project_root: {{ proj_path }}/{{ deploy_name }}
        upstream_server: unix://{{ proj_path }}/{{ deploy_name }}/var/uwsgi.sock
        port: {{ project['port'] }}
        servers: {{ project['servers'] }}
        http_basic_auth: {{ project.get('http_basic_auth', false) }}

{% if project.get('site_enabled', true) %}
chp|project={{ deploy_name }}|state=nginx:
  service.running:
    - name: nginx
    - reload: True
    - watch:
      - file: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
  file.symlink:
    - name: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
    - target: /etc/nginx/sites-available/{{ deploy_name }}.conf
{% endif %}

# Nginx-level HTTP Basic Authentication
{% if project.get('http_basic_auth', false) %}

{% for user in project.get('admins', []) %}
{% if pillar.get('users', {}).get(user, {}).get('htpasswd') %}
chp|project={{ deploy_name }}|http_basic_auth={{ user }}:
  file.append:
    - name: {{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd
    - text: {{ user }}:{{ pillar['users'][user]['htpasswd'] }}
    - makedirs: true
{% endif %}
{% endfor %}

{{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd:
  file.managed:
    - owner: www-data
    - mode: 400

{% endif %}   # End if project['http_basic_auth']


{% endif %}   # End if 'wsgi_module' in project


{% endfor %}  # End for deploy_name, project in wsgi_projects
