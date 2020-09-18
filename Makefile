include dev/.env
export
export PATH := $(shell pwd)/tmp:$(PATH)

# Presto version
PRESTO_VERSION = 341

.ONESHELL .PHONY: up update-box destroy-box remove-tmp clean example
.DEFAULT_GOAL := up

#### Pre requisites ####
install:
	 mkdir -p tmp;(cd tmp; git clone --depth=1 https://github.com/fredrikhgrelland/vagrant-hashistack.git; cd vagrant-hashistack; make install); rm -rf tmp/vagrant-hashistack

linter:
	docker run -e RUN_LOCAL=true -v "${PWD}:/tmp/lint/" github/super-linter

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

template-example: custom_ca
ifdef CI # CI is set in Github Actions
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant up --provision
else
	if [ -f "docker/conf/certificates/*.crt" ]; then cp -f docker/conf/certificates/*.crt template_example/docker/conf/certificates; fi
	cd template_example; SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} CUSTOM_CA=${CUSTOM_CA} ANSIBLE_ARGS='--extra-vars "local_test=true"' vagrant up --provision
endif

# clean commands
destroy-box:
	vagrant destroy -f

remove-tmp:
	rm -rf ./tmp

clean: destroy-box remove-tmp

status:
	vagrant global-status
# helper commands
update-box:
	@SSL_CERT_FILE=${SSL_CERT_FILE} CURL_CA_BUNDLE=${CURL_CA_BUNDLE} vagrant box update || (echo '\n\nIf you get an SSL error you might be behind a transparent proxy. \nMore info https://github.com/fredrikhgrelland/vagrant-hashistack/blob/master/README.md#proxy\n\n' && exit 2)

# to-hivemetastore
proxy-h:
	consul connect proxy -service hivemetastore-local -upstream hive-metastore:9083 -log-level debug
# to-minio
proxy-m:
	consul connect proxy -service minio-local -upstream minio:9090 -log-level debug
# to-postgres
proxy-pg:
	consul connect proxy -service postgres-local -upstream postgres:5432 -log-level debug
# to-presto
proxy-presto:
	consul connect proxy -service presto-local -upstream presto:8080 -log-level debug

presto-cli:
	docker run --rm -it --network host prestosql/presto:${PRESTO_VERSION} presto --server localhost:8080 --http-proxy localhost:8080 --catalog hive --schema default --user presto --debug
