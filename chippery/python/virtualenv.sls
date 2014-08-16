#!stateconf -o yaml . jinja
#
# Set up components required for basic Python development
########################################################################


# Install virtualenv, for Python virtual environments
.System-Python Virtualenv package:
  pkg.installed:
    - name: python-pip
  pip.installed:
    - name: virtualenv
    - require:
      - pkg: .System-Python Virtualenv package
