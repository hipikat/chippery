#
# Chippery entry-point - includes global states and formulas
# for whatever kinds of projects are defined in the pillar.
##########################################################

{% set chippery = pillar['chippery'] %}

# Required system packages
chippery_sys_pkgs:
  pkg.installed:
    - pkgs:
      - git               # Version control

# Project stacks!
{% if 'wsgi_projects' in chippery or 'php_projects' in chippery %}
include:
  {% if 'wsgi_projects' in chippery %}
  - .wsgi_stack
  {% endif %}
  {% if 'php_projects' in chippery %}
  - .php_stack
  {% endif %}
{% endif %}
