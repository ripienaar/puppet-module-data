What?
=====

While hiera does a decent job of separating code and data for users
it is quite difficult for module authors to use hiera to create reusable
modules. This is because the puppet backend is optional and even when
it is loaded the module author cannot influence the hierarchy.

With this commit we add a new module_data backend that loads data from
within a module and allow the module author to set a hierarchy for this
data.

The goal of this backend is to allow module authors to specify true
module default data in their modules but still allow users to override
the data using the standard method - especially useful with the puppet 3
hiera integration.

This backend is always loaded as the least important tier in the
hierarchy - unless a user choose to put it somewhere specific, but this
backend will always be enabled.

Given a module layout:

    your_module
    ├── data
    │   ├── hiera.yaml
    │   └── osfamily
    │       ├── Debian.yaml
    │       └── RedHat.yaml
    └── manifests
        └── init.pp

The hiera.yaml is optional in this example it would be:

    ---
    :hierarchy:
    - osfamily/%{::osfamily}
    - common

But when no hiera.yaml exist in the module, the default would be:

    ---
    :hierarchy:
    - common

The data directory is then a standard Hiera data store.

Status?
-------

This is but a first stab at turning my old pull request for ticket 16856
into a standalone module that any > 3.0.0 Puppet user can depend on to
get this essential feature.

Some more testing is needed, sanity checking for support versions etc so
consider this a early feedback-saught release

Contact?
--------

R.I.Pienaar / rip@devco.net / @ripienaar / http://devco.net
