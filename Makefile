include dev/.env
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
dev-standalone: update-box custom_ca
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--skip-tags "test" --extra-vars "\"mode=standalone\""' vagrant up --provision

dev: update-box custom_ca
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--skip-tags "test" --extra-vars "\"mode=cluster\""' vagrant up --provision

custom_ca:
ifdef CUSTOM_CA
	cp -f ${CUSTOM_CA} docker/conf/certificates/
endif

up-standalone: update-box custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='--extra-vars "\"ci_test=true mode=standalone\""' vagrant up --provision
else
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "\"mode=standalone\""' vagrant up --provision
endif

up: update-box custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='--extra-vars "\"ci_test=true mode=cluster\""' vagrant up --provision
else
	SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "\"mode=cluster\""' vagrant up --provision
endif

test-standalone: clean up-standalone

test: clean up

template_example: custom_ca
ifeq ($(GITHUB_ACTIONS),true) # Always set to true when GitHub Actions is running the workflow. You can use this variable to differentiate when tests are being run locally or by GitHub Actions.
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} ANSIBLE_ARGS='--extra-vars "ci_test=true"' vagrant up --provision
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

clean: destroy-box remove-tmp

# helper commands
update-box:
	@SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant box update || (echo '\n\nIf you get an SSL error you might be behind a transparent proxy. \nMore info https://github.com/fredrikhgrelland/vagrant-hashistack/blob/master/README.md#proxy\n\n' && exit 2)

# to-hivemetastore
proxy-hive:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service hivemetastore-local -upstream hive-metastore:9083 -log-level debug
# to-minio
proxy-minio:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service minio-local -upstream minio:9090 -log-level debug
# to-postgres
proxy-postgres:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service postgres-local -upstream postgres:5432 -log-level debug
# to-presto
proxy-presto:
	docker run --rm -it --network host consul:1.8 consul connect proxy -token master -service presto-local -upstream presto:8080 -log-level debug

presto-cli:
	CID=$$(docker run --rm -d --network host consul:1.8 connect proxy -token master -service presto-local -upstream presto:8080)
	docker run --rm -it --network host prestosql/presto:${PRESTO_VERSION} presto --server localhost:8080 --http-proxy localhost:8080 --catalog hive --schema default --user presto --debug
	docker rm -f $$CID

pre-commit: check_for_docker_binary check_for_terraform_binary
	docker run -e RUN_LOCAL=true -v "${PWD}:/tmp/lint/" github/super-linter
	terraform fmt -recursive && echo "\e[32mTrying to prettify all .tf files.\e[0m"


# MAC
# docker run --rm -d --network test1 consul:1.8 connect proxy -http-addr=http://host.docker.internal:8500 -token=master -service=presto-local -upstream=presto:8080
# docker run --rm -d -p 8080:8080 consul:1.8 connect proxy -http-addr=http://host.docker.internal:8500 -token=master -service=presto-local -upstream=presto:8080
# docker run --rm -it prestosql/presto:341 presto --server=host.docker.internal:8080 --http-proxy=host.docker.internal:8080 --catalog=hive --schema=default --user=presto --debug
# consul connect proxy -token master -service presto-local -upstream presto:8080

# docker run --rm consul:1.8 connect proxy -http-addr http://host.docker.internal:8500 -token master -service presto-local -upstream presto:8080
#-service frontend \
#    -service-addr 127.0.0.1:8080 \
#    -listen ':8443'

cli1:
	CID=$$(docker run --rm -d --name=prayproxy --network test1 -p 8080:8080 consul:1.8 connect proxy -http-addr=http://host.docker.internal:8500 -token=master -service=presto-local -upstream=presto:8080)
	docker run --rm -it prestosql/presto:${PRESTO_VERSION} presto --server=host.docker.internal:8080 --http-proxy=host.docker.internal:8080 --catalog=hive --schema=default --user=presto --debug
	docker rm -f $$CID

d:
	docker run --rm \
		--name=pray \
		-p 8080:8080 \
		-p 8888:8888 \
		consul:1.8 \
		connect proxy \
		-http-addr=http://host.docker.internal:8500 \
		-token=master \
		-service=presto-local \
		-service-addr 0.0.0.0:8080 \
		-listen ':8888' \
		-upstream=presto:8080 \
		-log-level=debug
