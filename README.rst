########
Chippery
########

**NB: This project is 'pre-alpha'. :)**

**Short version:** Chippery makes the configuration and deployment of
WSGI_ web applications a breeze, for production and development.

.. _WSGI: http://en.wikipedia.org/wiki/Web_Server_Gateway_Interface

**Long version**: Deployment of modern web stacks just `isn't as easy as it
used to be`_. Chippery is a componentised set of Salt_ formulas, capable
of setting up the WSGI-based web stack you need to serve sites in
production, or in development configurations as close to production as
you'd like.

.. _isn't as easy as it used to be: https://twitter.com/pypikat/status/433788221449707520
.. _Salt: http://www.saltstack.com

For simple web projects you probably won't have to touch a single
service configuration file. Given a fresh VM and a small project
definition, Chippery can:

- Set up Pyenv_, so your projects can use any Python version
- Install Virtualenv_ and Virtualenvwrapper_
- Configure Virtualenvwrapper to be shared by system users
- Set up Nginx_ as the web server
- Check your WSGI project out of a git_ repository
- Set up a virtual environment for your project, with any Python version
- Add any extra `Python paths`_ you need to the virtual environment
- Check out and optionally `pip-[editable-]install`_ extra libraries
- Associate your project with its virtual environment, `for Virtualenvwrapper`_
- Make `PostgreSQL`_ databases and database user accounts you need
- Create deploy-specific environment variable files (consumable by `envdir`_)
- `Run`_ any 'post install' commands, with 'only if' checks
- Set up `uWSGI`_ as an app server, in your project's virtual environment
- Create a job with `Supervisor`_ for your project's app server
- Set Nginx `server blocks`_, associating hosts, ports etc. with your app
- Add any `other directives`_ you need to the server's configuration
- Set up `HTTP basic access authentication`_, if you'd like it
- Set sensible permissions all over the place

.. _Pyenv: https://github.com/yyuu/pyenv
.. _Virtualenv: http://www.virtualenv.org/
.. _Virtualenvwrapper: http://virtualenvwrapper.readthedocs.org/
.. _Nginx: http://nginx.org/
.. _git: http://git-scm.com
.. _Python paths: http://docs.python.org/2/library/sys.html#sys.path
.. _pip-[editable-]install: http://pip.readthedocs.org/en/latest/reference/pip_install.html#editable-installs
.. _for Virtualenvwrapper: http://virtualenvwrapper.readthedocs.org/en/latest/command_ref.html#setvirtualenvproject
.. _PostgreSQL: http://www.postgresql.org
.. _envdir: http://envdir.readthedocs.org/
.. _Run: http://docs.saltstack.com/ref/states/all/salt.states.cmd.html#salt.states.cmd.run
.. _uWSGI: http://uwsgi-docs.readthedocs.org/en/latest/
.. _Supervisor: http://supervisord.org
.. _server blocks: http://nginx.org/en/docs/http/ngx_http_core_module.html#server
.. _other directives: http://nginx.org/en/docs/http/ngx_http_core_module.html#directives
.. _HTTP basic access authentication: http://en.wikipedia.org/wiki/Basic_access_authentication

************
How it works
************

It's a regular Salt formula, using the default YAML/Jinja2 renderer.

With Salt installed, all you have to do is:

1. `Create a Jinja2 macro to define a project <#projects-fat-jinja2-macros>`__
2. `Set up your pillar's 'chippery' dictionary <#deployments-pillar-stacks>`__
3. `Include the formula on targeted minions <#activation-the-chippery-formula>`_

Projects: Fat Jinja2 Macros
===========================

.. _Set up your pillar's 'chippery' dictionary:

Deployments: Pillar stacks
==========================

.. _Include the formula on targeted minions:

Activation: The Chippery formula
================================


**************
Where it works
**************

Chippery is being developed to target Ubuntu 13.10 (Saucy Salamander).
Once the API has been stabilised, the next goal will be the latest
Ubuntu LTS, 12.04 (Precise Pangolin). A broad set of targets is the
long-term goal. You can help by submitting `pull requests`_!

.. _pull requests: https://github.com/hipikat/chippery-formula/pulls

[More to come soon; this documentation is currently being written]
