#!stateconf -o yaml . jinja
#
# Set up the minion as a basic Python/WSGI development box
########################################################################


include:
  - chippery.nginx
  - chippery.stacks.python_dev
