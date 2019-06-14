install bioprotocol:
    builder.git_latest:
        - name: git@github.com:elifesciences/bioprotocol-service.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/bioprotocol/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True

    file.directory:
        - name: /srv/bioprotocol
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - builder: install bioprotocol

cfg file:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /srv/bioprotocol/app.cfg
        - source: 
            - salt://bioprotocol/config/srv-bioprotocol-app.cfg
        - template: jinja
        - require:
            - install bioprotocol

# if bioprotocol code has changed, delete venv so ./install.sh re-installs anything that may have changed
reinstall venv on changes:
    cmd.run:
        - cwd: /srv/bioprotocol
        - name: rm -rf venv
        - onchanges:
            - builder: install bioprotocol

configure bioprotocol:
    cmd.run:
        - user: {{ pillar.elife.deploy_user.username }}
        - cwd: /srv/bioprotocol/
        - name: |
            ./install.sh
        - require:
            - reinstall venv on changes
            - cfg file
            - psql-app-db # builder-base-formula/salt/elife/postgresql-appdb.sls




# nginx+uwsgi config

app-nginx-conf:
    file.managed:
        - name: /etc/nginx/sites-enabled/bioprotocol.conf
        - template: jinja
        - source: salt://bioprotocol/config/etc-nginx-sites-enabled-bioprotocol.conf
        - require:
            - pkg: nginx-server
{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
            - cmd: web-ssl-enabled
{% endif %}
        - watch_in:
            # restart nginx if app config changes
            - service: nginx-server-service

app-uwsgi-conf:
    file.managed:
        - name: /srv/bioprotocol/uwsgi.ini
        - source: salt://bioprotocol/config/srv-bioprotocol-uwsgi.ini
        - template: jinja
        - require:
            - install bioprotocol
            - configure bioprotocol

uwsgi-bioprotocol.socket:
    service.running:
        - enable: True

app-uwsgi:
    service.running:
        - name: uwsgi-bioprotocol
        - enable: True
        - require:
            - uwsgi-bioprotocol.socket
            - app-uwsgi-conf
            - app-nginx-conf
            - configure bioprotocol
        - watch:
            # restart uwsgi if bioprotocol code changes
            - install bioprotocol
            # restart uwsgi if bioprotocol config changes
            - cfg file
            # restart uwsgi if app's uwsgi conf changes
            - app-uwsgi-conf
        # restart nginx if uwsgi restarts
        - watch_in:
            - service: nginx-server-service




#
# article update listener
#

# credentials are required to read messages from the SQS queue
aws-credentials:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /home/{{ pillar.elife.deploy_user.username }}/.aws/credentials
        - source: salt://elife/templates/aws-credentials
        - defaults:
            access_id: {{ pillar.bioprotocol.aws.access_key_id }}
            secret_access_key: {{ pillar.bioprotocol.aws.secret_access_key }}
            region: {{ pillar.bioprotocol.aws.region }}
        - template: jinja
        - makedirs: True

update-listener-systemd:
    file.managed:
        - name: /lib/systemd/system/update-listener.service
        - source: salt://bioprotocol/config/lib-systemd-system-update-listener.service
        - makedirs: True
        - template: jinja
        - require:
            - configure bioprotocol

update-listener:
    {% if pillar.elife.env not in ['ci', 'end2end', 'prod', 'continuumtest'] %}
    service.dead:
    {% else %}
    service.running:
    {% endif %}
        - name: update-listener
        - enable: True
        - require:
            - file: update-listener-systemd
        - watch:
            # restart article listener if it's code changes
            - install bioprotocol
            # restart article listener if it's service config changes
            - update-listener-systemd
            # restart article listener if AWS credentials change
            - aws-credentials
