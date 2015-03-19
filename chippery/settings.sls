#!stateconf -o yaml . jinja
#
# Machine-wide settings
########################################################################

{% set chippery = pillar.get('chippery', {}) %}
{% set settings = chippery.get('settings', {}) %}


