



# Additional libraries required by the project, sourced via git
{% if 'libdir' in project and 'libs' in project: %}
{% for dest, git_url in project['libs'].iteritems(): %}
{{ deploy_name }}-lib-{{ dest }}:
  git.latest:
    - name: {{ git_url }}
    - target: {{ proj_path }}/{{ deploy_name }}/{{ project['libdir'] }}/{{ dest }}
{% endfor %}
{% endif %}

# Post-install hooks
# TODO: Work out why the hell the onlyif clause isn't working.
{% if 'post_install' in project: %}
{% for hook_name, hook in project['post_install'].iteritems(): %}
{% set cwd = '{{ proj_path }}/' ~ deploy_name %}
{{ deploy_name }}-post_install-{{ hook['run'] }}:
  cmd.run:
    - cwd: {{ cwd }}
    - name: {{ hook['run'] }}
    - user: root
{% if 'onlyif' in hook %}
    - onlyif:
      - {{ hook['onlyif']|replace('%cwd%', cwd) }}
{% endif %}
{% endfor %}
{% endif %}

# Supervisor uWSGI task
{% if 'wsgi_module' in project: %}
{{ deploy_name }}-pip-uwsgi:
  pip.installed:
    - name: uWSGI
    - bin_env: {{ venv_path }}/{{ deploy_name }}/bin/pip

/etc/supervisor/conf.d/{{ deploy_name }}.conf:
  file.managed:
    - source: salt://projects/templates/supervisor-uwsgi.conf
    - mode: 444
    - template: jinja
    - context:
        program_name: {{ deploy_name }}
        uwsgi_bin: {{ venv_path }}/{{ deploy_name }}/bin/uwsgi
        uwsgi_ini: {{ venv_path }}/{{ deploy_name }}/etc/uwsgi.ini

{{ venv_path }}/{{ deploy_name }}/etc:
  file.directory:
    - mode: 755

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

{{ venv_path }}/{{ deploy_name }}/etc/uwsgi.ini:
  file.managed:
    - source: salt://projects/templates/uwsgi-master.ini
    - mode: 444
    - makedirs: True
    - template: jinja
    - context:
        basicauth: {{ project.get('http_basic_auth', false) }}
        realm: {{ deploy_name }}
        htpasswd_file: {{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd
        socket: {{ venv_path }}/{{ deploy_name }}/var/uwsgi.sock
        wsgi_module: {{ project['wsgi_module'] }}
        virtualenv: {{ venv_path }}/{{ deploy_name }}
        uwsgi_log: /opt/var/{{ deploy_name }}/var/log/uwsgi.log

supervisor-update-{{ deploy_name }}:
  module.wait:
    - name: supervisord.update
    - watch:
      - file: /etc/supervisor/conf.d/{{ deploy_name }}.conf

run-{{ deploy_name }}-uwsgi:
  supervisord:
    - name: {{ deploy_name }}
    {% if 'run_uwsgi' in project and project['run_uwsgi']: -%}
    - running
    {%- else -%}
    - dead
    {%- endif %}

# Nginx hook-up
/etc/nginx/sites-available/{{ deploy_name }}.conf:
  file.managed:
    - source: salt://projects/templates/nginx-uwsgi-proxy.conf
    - mode: 444
    - template: jinja
    - context:
        project_name: {{ deploy_name }}
        project_root: {{ proj_path }}/{{ deploy_name }}
        upstream_server: unix://{{ proj_path }}/{{ deploy_name }}/var/uwsgi.sock
        port: {{ project['port'] }}
        servers: {{ project['servers'] }}
        http_basic_auth: {{ project.get('http_basic_auth', false) }}

{% if project.get('enabled', false) %}
{{ deploy_name }}-nginx:
  service.running:
    - name: nginx
    - reload: True
    - watch:
      - file: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
  file.symlink:
    - name: /etc/nginx/sites-enabled/{{ deploy_name }}.conf
    - target: /etc/nginx/sites-available/{{ deploy_name }}.conf
{% endif %}

# HTTP Basic Authentication
{% if project.get('http_basic_auth', false) %}
{% for user in project.get('admins', []) %}
{{ deploy_name }}-{{ user }}-http_basic_auth:
  file.append:
    - name: {{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd
    - text: {{ user }}:{{ pillar['users'][user]['htpasswd'] }}
    - makedirs: true
{% endfor %}

{{ venv_path }}/{{ deploy_name }}/etc/{{ deploy_name }}.htpasswd:
  file.managed:
    - owner: www-data
    - mode: 440
{% endif %}


{% endif %}   # End if 'wsgi_module' in project
