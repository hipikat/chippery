#!stateconf -o yaml . jinja
#
# Core Chippery states
########################################################################


# Install template for a user shell environment setup script. This is just an
# empty shell script which other parts of Chippery append to with blockreplace.
.Install Chippery's shared environment loader script:
  file.managed:
    - name: /usr/local/bin/set_chippery_env.sh
    - source: salt://chippery/templates/set_chippery_env.sh
    - replace: False
    - user: root
    - group: root
    - mode: 555
