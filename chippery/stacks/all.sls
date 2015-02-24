#!stateconf -o yaml . jinja
#
# Ensure all the software stacks we deal with natively are installed
########################################################################


include:
  - chippery.nginx
  - chippery.stacks.python_dev
