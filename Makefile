keysize = 4096
dn = /C=GB/ST=London/L=London/O=Home Office/OU=IT

.PHONY: all clean certs

all: certs

clean:
	rm -rf .docker-compose

certs: .docker-compose .docker-compose/source.crt .docker-compose/source.key .docker-compose/target.crt .docker-compose/target.key

.docker-compose:
	mkdir -p .docker-compose

%.key:
	openssl genrsa -out "$@" "$(keysize)"

%.crt: %.key
	cat "$<"
	openssl req \
		-new \
		-x509 \
		-sha256 \
		-days 365 \
		-key "$<" \
		-subj "$(DN)/CN=$(notdir $(basename $@))" \
		-out "$@"
