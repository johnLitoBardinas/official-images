#!/bin/bash
set -eo pipefail

# Test basic mosquitto broker and clients operation.
#
# 1. Run the broker. 
# 2. Use mosquitto_pub to publish a retained message with a random payload to a
#    random topic
# 3. Use mosquitto_sub to subscribe to the random topic, and retrieve the
#    payload.
# 
# mosquitto_sub times out after two seconds if the message is not delivered.

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

cname="eclipse-mosquitto-container-$RANDOM-$RANDOM"
cid="$(docker run -d \
	--name "$cname" \
	"$image"
)"
trap "docker rm -vf $cid > /dev/null" EXIT

_publish() {
	local topic="${1}"
	shift

	local payload="${1}"
	shift

	docker run --rm \
		--link "$cname":eclipse-mosquitto \
		"$image" \
		mosquitto_pub \
			-t $topic \
			-m ${payload} \
			-r \
			-h eclipse-mosquitto
}

_subscribe() {
	local topic="${1}"
	shift

	docker run --rm \
		--link "$cname":eclipse-mosquitto \
		"$image" \
		mosquitto_sub \
			-t $topic \
			-C 1 \
			-W 2 \
			-h eclipse-mosquitto
}

topic="topic-$RANDOM"
payload="$RANDOM"

. "$dir/../../retry.sh" --tries 20 "_publish $topic $payload"

response="$(_subscribe $topic)"
[[ "$response" == "$payload" ]]
