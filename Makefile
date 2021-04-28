include dev/.env
export PATH := $(shell pwd)/tmp:$(PATH)

# Trino version
TRINO_VERSION = 354

.ONESHELL .PHONY: up update-box destroy-box remove-tmp clean example trino-cli build-plugin
.DEFAULT_GOAL := up

#### Pre requisites ####
install:
	 mkdir -p tmp;(cd tmp; git clone --depth=1 https://github.com/skatteetaten/vagrant-hashistack.git; cd vagrant-hashistack; make install); rm -rf tmp/vagrant-hashistack

linter:
	docker run -e RUN_LOCAL=true -v "${PWD}:/tmp/lint/" github/super-linter

check_for_consul_binary:
ifeq (, $(shell which consul))
	$(error "No consul binary in $(PATH), download the consul binary from here :\n https://www.consul.io/downloads\n\n' && exit 2")
endif

check_for_terraform_binary:
ifeq (, $(shell which terraform))
	$(error "No terraform binary in $(PATH), download the terraform binary from here :\n https://www.terraform.io/downloads.html\n\n' && exit 2")
endif

check_for_docker_binary:
ifeq (, $(shell which docker))
	$(error "No docker binary in $(PATH), install docker from here :\n https://docs.docker.com/get-docker/\n\n' && exit 2")
endif

#### Development ####
# start commands
dev-standalone: update-box custom_ca build-plugin
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='-v --skip-tags "test" --extra-vars "\"mode=standalone\""' vagrant up --provision

dev: update-box custom_ca build-plugin
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='-v --skip-tags "test" --extra-vars "\"mode=cluster\""' vagrant up --provision

build-plugin:
	(cd java; mvn package)

custom_ca:
ifdef CUSTOM_CA
	cp -f ${CUSTOM_CA} docker/conf/certificates/
endif

up-standalone: update-box custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='-v --extra-vars "\"ci_test=true mode=standalone\""' vagrant up --provision
else
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='-v --extra-vars "\"mode=standalone\""' vagrant up --provision
endif

up: update-box custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='-v --extra-vars "\"ci_test=true mode=cluster\""' vagrant up --provision
else
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='-v --extra-vars "\"mode=cluster\""' vagrant up --provision
endif

test-standalone: clean up-standalone

test: clean up

template_example: custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='-v --extra-vars "ci_test=true"' vagrant up --provision
else
	if [ -f "docker/conf/certificates/*.crt" ]; then cp -f docker/conf/certificates/*.crt template_example/docker/conf/certificates; fi
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} vagrant up --provision
endif

status:
	vagrant global-status

# clean commands
destroy-box:
	vagrant destroy -f

remove-tmp:
	rm -rf ./tmp
	rm -rf ./.vagrant
	rm -rf ./dev/tmp
	rm -rf ./.minio.sys
	rm -rf ./example/**/.terraform*
	rm -rf ./example/**/*.tfstate

clean: destroy-box remove-tmp

# helper commands
update-box:
	@SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant box update || (echo '\n\nIf you get an SSL error you might be behind a transparent proxy. \nMore info https://github.com/skatteetaten/vagrant-hashistack/blob/master/README.md#proxy\n\n' && exit 2)

# to-hivemetastore
proxy-hive:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service hivemetastore-local -upstream hive-metastore:9083 -log-level debug
# to-minio
proxy-minio:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service minio-local -upstream minio:9090 -log-level debug
# to-postgres
proxy-postgres:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service postgres-local -upstream postgres:5432 -log-level debug
# to-trino
proxy-trino:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service trino-local -upstream trino:8080 -log-level debug

trino-cli:
	CID=$$(docker run --rm -d --network host consul:1.8 connect proxy -token master -service trino-local -upstream trino:8080)
	docker run --rm -it --network host trinodb/trino:${TRINO_VERSION} trino --server localhost:8080 --http-proxy localhost:8080 --catalog hive --schema default --user trino --debug
	docker rm -f $$CID

pre-commit: check_for_docker_binary check_for_terraform_binary
	docker run -e RUN_LOCAL=true -v "${PWD}:/tmp/lint/" github/super-linter
	terraform fmt -recursive && echo "\e[32mTrying to prettify all .tf files.\e[0m"
