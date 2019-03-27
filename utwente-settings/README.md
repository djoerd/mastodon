Install Mastodon U. Twente
==========================

This is a guide to installing Mastodon v2.3.3 on https://mastodon.utwente.nl

Do the following as the admin user (The Database Group 'beheer' account)

Update Ubuntu 16.04

    sudo apt-get dist-upgrade
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get autoremove

Install Nginx (and remove old Hadoop stuff)

    sudo apt-get install nginx
    sudo rm /etc/apt/sources.list.d/cloudera.list
    sudo apt-get remove hadoop-yarn-nodemanager hadoop-hdfs-datanode 
    sudo apt-get remove hadoop-mapreduce
    sudo apt-get remove oracle-java7-installer
    
Firewall settings

    sudo bash
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow ssh
    ufw allow www
    ufw allow https
    ufw enable
    ufw status

Set a login message that scares people away

    sudo vi /etc/motd

The remainder is based on the [Mastodon guide](https://github.com/tootsuite/documentation/blob/master/Running-Mastodon/Production-guide.md)

    curl -sL https://deb.nodesource.com/setup_6.x | bash -
    apt-get install nodejs
    apt-get update

    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
    apt update

    apt -y install imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev file git-core g++ libprotobuf-dev protobuf-compiler pkg-config nodejs gcc autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev nginx redis-server redis-tools postgresql postgresql-contrib letsencrypt yarn libidn11-dev libicu-dev

For technical reasons (we use a centralized user database), we're
adding the user mastodon under `/local`: 

    # ignore the Kerberos password
    adduser --home /local/mastodon mastodon
    # manually add a password (I created a user on my laptop to get it)
    vi /etc/passwd
    # change '!' to '*'
    vi /etc/shadow
    # mastodon:ENCRYPTEDPASSWORDHERE:17617:0:99999:7:::
    su mastodon

We will need to set up rbenv and ruby-build:

    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    cd ~/.rbenv && src/configure && make -C src
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    # Restart shell
    exec bash
    # Check if rbenv is correctly installed
    type rbenv
    # Install ruby-build as rbenv plugin
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    rbenv install 2.5.0
    rbenv global 2.5.0

Now get Mastodon! (TODO: merge the branch `feature-utwente` with the master) 

    cd /local/mastodon
    git clone https://github.com/djoerd/mastodon.git live
    cd live
    # Checkout to the latest stable branch
    git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
    # Install bundler
    gem install bundler
    # Use bundler to install the rest of the Ruby dependencies
    bundle install -j$(getconf _NPROCESSORS_ONLN) --deployment --without development test
    # Use yarn to install node.js dependencies
    yarn install --pure-lockfile

PostgreSQL (in case of encoding errors, [recreate template1](https://stackoverflow.com/questions/13115692/encoding-utf8-does-not-match-locale-en-us-the-chosen-lc-ctype-setting-requires#17565205))

    sudo bash
    su postgres
    psql
    # In the following prompt
    CREATE USER mastodon CREATEDB;
    \q
     
Nginx config (Use U. Twente SSL signing instead of Letsencrypt, thnx Johan Moelaert)

    mkdir /etc/nginx/ssl 
    mkdir /etc/nginx/ssl/mastodon
    cd /etc/nginx/ssl/mastodon
    # generate key:
    openssl  genrsa -out mastodon.key 2048
    # make csr (send mastodon.csr to LISA to get it signed by U. Twente):
    openssl req -new -key mastodon.key -out mastodon.csr
    # Country Name (2 letter code) [AU]:NL
    # State or Province Name (full name) [Some-State]:Overijssel
    # Locality Name (eg, city) []:Enschede
    # Organization Name (eg, company) [Internet Widgits Pty Ltd]:University of Twente
    # Organizational Unit Name (eg, section) []:EWI
    # Common Name (e.g. server FQDN or YOUR name) []:mastodon.utwente.nl
    # Email Address []:
    # 
    # make a selfsigned key:
    openssl x509 –req –sha256 –in mastodon.csr –signkey mastodon.key –out mastodon.self.crt
    # show your certificate:
    openssl x509 –tekst –in mastodon.self.crt -noout
    cp /local/mastodon/live/utwente-settings/nginx/mastodon.utwente.nl.conf /etc/nginx/sites-available/.
    cp /local/mastodon/live/utwente-settings/nginx/maintenance.conf /etc/nginx/sites-available/.
    ln -s /etc/nginx/sites-available/mastodon.utwente.nl.conf /etc/nginx/sites-enabled/.
    /etc/init.d/nginx restart

Mastodon application configuration

    su mastodon
    cd /local/mastodon/live
    RAILS_ENV=production bundle exec rake mastodon:setup

Mastodon systemd Service Files

    sudo bash 
    cp /local/mastodon/live/utwente-settings/services/* /etc/systemd/system/.
    systemctl enable /etc/systemd/system/mastodon-*.service
    systemctl start mastodon-web.service
    systemctl start mastodon-sidekiq.service
    systemctl start mastodon-streaming.service
    systemctl status mastodon-*.service # check

Cron for: Remote media attachment cache cleanup, media backups, and database dump:
(`/home/hiemstra` is mounted from another machine and also backuped, so we have additional safety)

    su mastodon
    crontab -e
        RAILS_ENV=production
        @daily cd /local/mastodon/live && /local/mastodon/.rbenv/shims/bundle exec rake mastodon:media:remove_remote 
        @daily rsync -av /data/mastodon/public/system /home/hiemstra/backups/mastodon/live/public/ 
        @daily pg_dump mastodon_production >"/home/hiemstra/backups/mastodon/dump-$(date +\%a).sql"

## That's it, we're live!

Additionally, we moved the media and PosgreSQL data to another (bigger) disk under `/data`:

    sudo bash
    mkdir /data/mastodon
    chown mastodon:root mastodon
    su mastodon
    rsync -av /local/mastodon/live/public/system /data/mastodon/public/
    rm -rf /local//mastodon/live/public/system
    ln -s /data/mastodon/public/system /local/mastodon/live/public/.

    sudo bash
    systemctl stop postgresql
    systemctl status postgresql
    mkdir /data/postgres
    chown postgres:root /data/postgres
    su postgres
    rsync -av /var/lib/postgresql/9.5 /data/postgres/
    vi /etc/postgresql/9.5/main/postgresql.conf
        data_directory = '/data/postgres/9.5/main'
    systemctl start postgresql
    psql
        SHOW data_directory;

You don't have backups, unless you tested them: How to restore the PostgreSQL dump:

    su mastodon
    psql template1
        create database mastodon_production   
    psql mastodon_production -f dumpfile.sql
    su postgres (to fix revoke/grant warnings, no sure if necessary)
    psql mastodon_production
        REVOKE ALL ON SCHEMA public FROM PUBLIC;
        REVOKE ALL ON SCHEMA public FROM postgres;
        GRANT ALL ON SCHEMA public TO postgres;
        GRANT ALL ON SCHEMA public TO PUBLIC;

Adding support for Latex:

    # Use this [patch](https://gist.github.com/christianp/222cebfa0a3c9d0062f793e98ef4e6ad)
    wget https://github.com/mathjax/MathJax/archive/master.zip
    unzip master.zip
    mv MathJax ~/live/public/.

To update to a newer Mastodon version:

    # Update Ubuntu 16.04
    sudo apt-get dist-upgrade
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get autoremove

    # update the utwente repository (github.com/djoerd/mastodon)
    su mastodon
    cd ~/mastodon
    git remote add tootsuite https://github.com/tootsuite/mastodon.git
    git checkout master
    git pull tootsuite master --tags
    git push --tags
    # in case you mess up the repo:
    git push -f origin LASTCOMMITNUMBER:master

    # make a backup, now
    rsync -av /data/mastodon/public/system /home/hiemstra/backups/mastodon/live/public/
    pg_dump mastodon_production >"/home/hiemstra/backups/mastodon/dump-$(date +\%a).sql"

    #pull the site off-line and set a 503 maintenance page
    sudo ln -s -f /etc/nginx/sites-available/maintenance.conf /etc/nginx/sites-enabled/mastodon.utwente.nl.conf
    sudo /etc/init.d/nginx restart

    # in the live repository: [update as follows](https://github.com/tootsuite/documentation/blob/master/Running-Mastodon/Updating-Mastodon-Guide.md)
    # check the [release notes](https://github.com/tootsuite/mastodon/releases/)
    su mastodon
    cd ~/live
    git fetch --tags
    git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
    rbenv install 2.5.1
    rbenv global 2.5.1
    gem install bundler # new Ruby? Install bundler again!
    bundle install
    yarn install
    RAILS_ENV=production bundle exec rails db:migrate
    RAILS_ENV=production bundle exec rails assets:precompile

    # Remove 503 page
    sudo ln -s -f /etc/nginx/sites-available/mastodon.utwente.nl.conf /etc/nginx/sites-enabled/mastodon.utwente.nl.conf
    sudo reboot
 
Encore, How to run a Mastodon bot (using: https://anarcat.gitlab.io/feed2exec/)

    python3 -m feed2exec add news https://www.utwente.nl/en/news.rss --output feed2exec.plugins.exec --args "/home/hiemstra/bin/toot_news news@mastodon.utwente.nl '{item.title} {item.link}'"

where `toot_news` is:

    #!/bin/bash
    set -e
    set -u
    /usr/local/bin/toot activate $1
    /usr/local/bin/toot post "$2"

