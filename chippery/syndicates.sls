#!stateconf -o yaml . jinja
#
# Ensure the existence of syndicated minions
########################################################################


{% set syndicates = chippery.get('syndicates', {}) %}

{% for cluster_name, cluster in syndicates.items() %}

  {% if cluster is not mapping %}
    {% set cluster = {'map': cluster} %}
  {% endif %}

  {% set cluster_map = pillar[map_name] %}
  {% for profile_group, group_settings in cluster_map.items() %}

    {% for minion_count in range(1, group_settings.get('count', 1)) %}
    
      {% if minion_count == 1 and group_settings.get('count', 1) == 1 %}
        {% set minion_n = '' %}
      {% else %} 
        {% set minion_n = minion_count %}
      {% endif %}
      {% set minion_name = cluster_name ~ '-' ~ profile_group ~ minion_count %}

.Ensure minion {{ minion_name }} exists:
  cloud.profile:
    - name: {{ minion_name }}
    - profile: {{ group_settings['profile'] }}



    {% endfor %}



  {% endfor %}

{% endfor %}
