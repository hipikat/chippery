#
# Requirements for all types of Chippery project stacks
########################################################################


# Required system packages
chippery_sys_pkgs:
  pkg.installed:
    - pkgs:
      - git               # Version control

#/etc/login.defs:
#  file.patch:
#    - source: salt://chippery/templates/login.defs.patch
#    - hash: md5=75582eaf0722a1a0bb09427c14870280

#/etc/login.defs:
#  file.sed:
#    - before: "UMASK\s*[\dx]\+\s*"
#    - after: "UMASK\s*002\s*"

/etc/login.defs:
  file.replace:
    - pattern: ^UMASK\s+[\dx]+
    - repl: UMASK\t\t002
    - flags: ['IGNORECASE']
    - backup: False
