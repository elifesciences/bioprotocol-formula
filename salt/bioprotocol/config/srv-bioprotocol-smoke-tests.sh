#!/bin/bash
set -ex

test $(curl -s "http://127.0.0.1/ping" --output /dev/null --write-out '%{http_code}') = 200
test $(curl -s "http://127.0.0.1/status" --output /dev/null --write-out '%{http_code'}) = 200

function post {
    user=$1
    pass=$2
    curl \
        --silent \
        --request POST \
        --output /dev/null \
        --write-out '%{http_code}' \
        --header "Content-Type: application/json" \
        --data "{}" \
        --user "$user:$pass" \
        "http://127.0.0.1/bioprotocol/article/0"
}

# ensure no unauthenticated requests can POST
test $(post "nouser" "nopass") = 401

# ensure all configured web users can POST
{% for _, user in pillar.elife.web_users.items() -%}
test $(post "{{ user.username }}" "{{ user.password }}") = 400 # authenticated, but bad request (bad data)
{% endfor %}
