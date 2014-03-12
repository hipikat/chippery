#
# System-wide always-defined environment variable control
##########################################################

{% set chippery = pillar['chippery'] %}


/etc/chippery:
  file.managed:
    - source: salt://chippery/sysenv/templates/chippery
    - mode: 555

/etc/chippery.d:
  file.directory:
    - dir_mode: 775
    - file_mode: 444
    - user: root
    - group: root
    - recurse:
      - user
      - group
      - mode

{% for user in chippery['sysadmins'] %}
chp|sysenv|user={{ user }}:
  file.blockreplace:
    - name: /home/{{ user }}/.bashrc
    - marker_start: "# START managed zone chippery|sysenv"
    - marker_end: "# END managed zone chippery|sysenv"
    - content: 'source /etc/chippery'
    - prepend_if_not_found: True
    - show_changes: True
{% endfor %}
