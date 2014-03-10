#
# Python setup with system-wide pyenv, virtualenv, virtualenvwrapper, etc.
##########################################################################

{% set chippery = pillar['chippery'] %}


# System-Python package manager
chp|system_python_pip:
  pkg.installed:
    - name: python-pip

# System-Python packages
{% for py_pkg in (
  'virtualenv',
  'virtualenvwrapper',
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
/etc/profile.d/virtualenvwrapper.sh:
  file:
    - managed
    - template: jinja
    - user: root
    - group: root
    - mode: 444 
    - source: salt://chippery/python/templates/init_virtualenvwrapper.sh
    - context:
        venv_path: {{ venv_path }}
        proj_path: {{ proj_path }}
    - require:
      - pip: chp|system_python_virtualenvwrapper
