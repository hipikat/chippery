#
# Chippery entry-point - includes global states and formulas
# for whatever kinds of projects are defined in the pillar.
#######################################################################

{% set chippery = pillar['chippery'] %}


# Include core requirements and project stacks
include:
  -  .core
  {% for stack_type in ('wsgi', 'php') %}
  {% if stack_type ~ '_projects' in chippery %}
  - .{{ stack_type }}_stack
  {% endif %}
  {% endfor %}
