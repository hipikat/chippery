#!stateconf -o yaml . jinja
#
# Install Varnish
########################################################################

include:
  - chippery.misc.ppa_requirements

.Varnish PPA for {{ grains['osfinger'] }}:
  pkgrepo.managed:
  - name: deb https://repo.varnish-cache.org/ubuntu/ {{ grains['oscodename'] }} varnish-4.0
  - key_url: http://repo.varnish-cache.org/debian/GPG-key.txt


