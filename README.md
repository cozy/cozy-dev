# Cozy Dev

Cozy Dev is a tool for Cozy Web Application developers. It makes easy to
start with building an application for the Cozy Cloud Platform.

    npm install cozy-dev -g
    cozy new myapp --github myaccount
    cd myapp

Add some features, then:

    cozy deploy

# Managing your virtual machine

Cozy Dev helps you to manage a virtual machine through Vagrant.

```
cozy dev:init
cozy dev:start

cozy dev:stop
```

More information about CozyCloud and virtual machines in [the documentation](http://cozy.io/hack/getting-started/setup-environment.html#for-applications-that-take-advantage-of-the-data-system).

## Hack

Get sources:

    git clone https://github.com/mycozycloud/cozy-dev.git

Run:

    cd cozy-dev
    chmod +x bin/cozy
    ./bin/cozy

Each modification requires a new build, here is how to run a build:

    cake build


## License

Cozy Manager is developed by Cozy Cloud and distributed under the LGPL v3 license.

## What is Cozy?

![Cozy Logo](https://raw.github.com/mycozycloud/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you with a new experience. You can install Cozy on your own
hardware where no one profiles you.

## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://groups.google.com/forum/?fromgroups#!forum/cozy-cloud)
* Posting issues on the [Github repos](https://github.com/mycozycloud/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
