include dev/.env
export
export PATH := $(shell pwd)/tmp:$(PATH)

# Presto version
PRESTO_VERSION = 341

.ONESHELL .PHONY: up update-box destroy-box remove-tmp clean example presto-cli
.DEFAULT_GOAL := up

#### Pre requisites ####
install:
	 mkdir -p tmp;(cd tmp; git clone --depth=1 https://github.com/fredrikhgrelland/vagrant-hashistack.git; cd vagrant-hashistack; make install); rm -rf tmp/vagrant-hashistack

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
dev: update-box custom_ca
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--skip-tags "test"' vagrant up --provision

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

template_example: custom_ca
ifdef CI # CI is set in Github Actions
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant up --provision
else
	if [ -f "docker/conf/certificates/*.crt" ]; then cp -f docker/conf/certificates/*.crt template_example/docker/conf/certificates; fi
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "local_test=true"' vagrant up --provision
endif

status:
	vagrant global-status

# clean commands
destroy-box:
	vagrant destroy -f

remove-tmp:
	rm -rf ./tmp
	rm -rf ./.vagrant
	rm -rf ./.minio.sys
	rm -rf ./example/.terraform
	rm -rf ./example/terraform.tfstate
	rm -rf ./example/terraform.tfstate.backup

clean: destroy-box remove-tmp

status:
	vagrant global-status
# helper commands
update-box:
	@SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant box update || (echo '\n\nIf you get an SSL error you might be behind a transparent proxy. \nMore info https://github.com/fredrikhgrelland/vagrant-hashistack/blob/master/README.md#proxy\n\n' && exit 2)

# to-hivemetastore
proxy-h:
	docker run --rm -it --network host consul:1.8 consul connect proxy -service hivemetastore-local -upstream hive-metastore:9083 -log-level debug
# to-minio
proxy-m:
	docker run --rm -it --network host consul:1.8 consul connect proxy -service minio-local -upstream minio:9090 -log-level debug
# to-postgres
proxy-pg:
	docker run --rm -it --network host consul:1.8 consul connect proxy -service postgres-local -upstream postgres:5432 -log-level debug
# to-presto
proxy-presto:
	docker run --rm -it --network host consul:1.8 consul connect proxy -service presto-local -upstream presto:8080 -log-level debug

presto-cli:
	CID=$$(docker run --rm -d --network host consul:1.8 connect proxy -service presto-local -upstream presto:8080)
	docker run --rm -it --network host prestosql/presto:${PRESTO_VERSION} presto --server localhost:8080 --http-proxy localhost:8080 --catalog hive --schema default --user presto --debug
	docker rm -f $$CID

pre-commit: check_for_docker_binary
	docker run -e RUN_LOCAL=true -v "${PWD}:/tmp/lint/" github/super-linter
	terraform fmt -recursive && echo "\e[32mTrying to prettify all .tf files.\e[0m"
