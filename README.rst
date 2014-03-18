********
Chippery
********

**NB: This project is 'pre-alpha', and under heavy development. :)**

Short version: Chippery makes deployment of WSGI_ web applications for
development and production, on your own VMs, a breeze.

.. _WSGI: http://en.wikipedia.org/wiki/Web_Server_Gateway_Interface

Long version: Deployment of modern web stacks just `isn't as easy as it
used to be`_. Chippery is a componentised set of Salt_ formulas, capable
of setting up the WSGI-based web stack you need to serve sites in
production - or development configurations as close to production as
you'd like. The rest of this description assumes a familiarity with
Salt. :)

.. _isn't as easy as it used to be: https://twitter.com/pypikat/status/433788221449707520
.. _Salt: http://www.saltstack.com

For simple web projects you probably won't have to touch a single
configuration file. Given a fresh VM and a small project definition,
Chippery will:

- Set up Pyenv to select between Python versions
- Set up Virtualenv and Virtualenvwrapper, to be used in a shared way by
  system users
- Set up Nginx as the web server
- Check your WSGI project out of a git repository
- Set up a virtual environment for your project, with any Python version
- Add any extra Python paths you need to the virtual environment
- Check out and optionally pip-[editable-]install extra libraries
- Associate your project with its virtual environment, for Virtualenvwrapper
- Set up PostgreSQL, project databases, project, and developer user
  accounts, for any projects in which they're specified
- Create deploy-specific environment variable files (consumable by Envdir)
- Run any 'post install' commands you need, with 'only if' checks
- Set up uWSGI as an app server, in your project's virtual environment
- Create a job with Supervisord for your project's uWSGI app server
- Set up configuration between specified virtual hosts, ports, etc in
  Nginx, pointing to your project's WSGI socket
- Add any other directives you need to the virtual host's configuration
- Set up HTTP basic authentication for users, if you'd like it
- Set sensible permissions all over the place


[more documentation to come...]
