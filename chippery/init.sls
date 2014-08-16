#
# Chippery entry-point - includes global states and formulas
# for whatever kinds of projects are defined in the pillar.
#######################################################################

{% set chippery = pillar.get('chippery', {}) %}

{% if chippery and chippery.get('enabled', true) != false %}
include:

  # States common to any minion using Chippery
  - .core

  # Machine-wide settings
  - .settings

  # Ensure the existence of defined virtual machines
  {% if 'syndicates' in chippery.values() %}
  - .syndicates
  {% endif %}

  # Install individual 'stacks', e.g. 'wsgi_dev'
  {% for stack in chippery.get('stacks', []) %}
    {% if stack is not mapping %}
      {% set stack = {'name': stack} %}
    {% endif %}
  - .stacks.{{ stack['name'] }}
  {% endfor %}

  # Install (and remove) projects
  {% if 'projects' in chippery %}
  - .projects
  {% endif %}


  #{% for project in chippery.get('projects', {}) %}
  #- .project.
  #{% endfor %}


  #{% for stack_type in ('wsgi', 'php') %}
  #{% if stack_type ~ '_projects' in chippery %}
  #- .{{ stack_type }}_stack
  #{% endif %}
  #{% endfor %}

{% endif %}
