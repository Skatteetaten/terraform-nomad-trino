include dev/.env
export
export PATH := $(shell pwd)/tmp:$(PATH)

.ONESHELL .PHONY: up update-box destroy-box remove-tmp clean example
.DEFAULT_GOAL := up

#### Development ####
# start commands
dev: update-box
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='--skip-tags "test"' vagrant up --provision

custom_ca:
ifdef CUSTOM_CA
	cp -f ${CUSTOM_CA} docker/conf/certificates/
endif

up: update-box custom_ca
ifdef CI # CI is set in Github Actions
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant up --provision
else
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "local_test=true"' vagrant up --provision
endif

test: clean up

example: custom_ca
ifdef CI # CI is set in Github Actions
	cd test_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant up --provision
else
	cp -f docker/conf/certificates/*.crt test_example/docker/conf/certificates
	cd test_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "local_test=true"' vagrant up --provision
endif

# clean commands
# clean commands
destroy:
	vagrant destroy -f
	rm terraform.tfstate || true
	rm terraform.tfstate.backup || true
	rm example/terraform.tfstate || true

remove-tmp:
	rm -rf ./tmp

clean: destroy-box remove-tmp

# helper commands
update-box:
	@SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant box update || (echo '\n\nIf you get an SSL error you might be behind a transparent proxy. \nMore info https://github.com/fredrikhgrelland/vagrant-hashistack/blob/master/README.md#if-you-are-behind-a-transparent-proxy\n\n' && exit 2)

# to-hivemetastore
proxy-h:
	consul connect proxy -service hivemetastore-local -upstream hive-metastore:9083 -log-level debug
# to-minio
proxy-m:
	consul connect proxy -service minio-local -upstream minio:9000 -log-level debug
# to-postgres
proxy-p:
	consul connect proxy -service postgres-local -upstream postgres:5432 -log-level debug
# to-presto
proxy-p:
	consul connect proxy -service postgres-local -upstream presto:8080 -log-level debug
