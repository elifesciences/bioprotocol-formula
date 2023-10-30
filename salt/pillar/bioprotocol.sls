bioprotocol:
    aws:
        access_key_id: AKIANOTANACTUALKEY
        secret_access_key: asdf34sd43a78fs872m')dsd98a2/asdf
        region: us-east-1

    app:
        secret: not-a-real-secret-key

    api_whitelist: []

elife:
    db:
        app:
            name: bioprotocol
            # username: 
            # password: 

    web_users:
        bioprotocol-:
            username: these-are-not-the-credentials
            password: you-are-looking-for
            # created with `caddy hash-password --plaintext <above password>`
            caddy_password_hash: "$2a$14$1um/p1.PfidsBf8JDofTmutenPgnu/x29WBG/eHjt.FwmuKk7DGt2"

    webserver: 
        app: caddy

    uwsgi:
        services:
            bioprotocol:
                folder: /srv/bioprotocol
                protocol: http-socket

