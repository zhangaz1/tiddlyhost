
_help:
	@echo Available tasks:
	@grep '^[^_#[:space:]][^=/[:space:]]*:' Makefile | cut -d: -f1 | xargs -n1 echo ' make'

# The build args are important here, the build will fail without them
build-base: cleanup cert
	docker-compose build --build-arg USER_ID=$$(id -u) --build-arg GROUP_ID=$$(id -g) base

build-prod:
	./etc/create-build-info.sh
	docker-compose -f docker-compose-prod.yml build prod

rails-init:
	docker-compose run --rm base bash -c "bundle install && \
	  bundle exec rails webpacker:install && \
	  bundle exec rails db:create && \
	  bundle exec rails db:migrate"

# Brings up the web container only and runs bash in it
run-base:
	-docker-compose run --rm --no-deps base bash

# Brings up the db and the web container and runs bash in the web container
shell:
	-docker-compose run --rm base bash

# Same thing but use the prod container
shell-prod:
	-docker-compose -f docker-compose-prod.yml run --rm prod bash

# Runs bash in an already running web container
join:
	-docker-compose exec base bash

# Same thing but use the prod container
join-prod:
	-docker-compose -f docker-compose-prod.yml exec prod bash

# Start the dev container
start:
	-docker-compose up

# Start the prod container locally
start-prod:
	-RAILS_MASTER_KEY=`cat rails/config/master.key` docker-compose -f docker-compose-prod.yml up

bundle-install:
	-docker-compose run --rm --no-deps base bash -c "bin/bundle install"

secrets:
	-docker-compose run --rm --no-deps base bash -c "EDITOR=vi bin/rails credentials:edit"

minikube-build-base:
	eval $$(minikube -p minikube docker-env) && $(MAKE) build-base

start-minikube:
	# Bring up k8s, show some info
	#minikube version
	#minikube start
	#kubectl version
	#kubectl cluster-info
	#kubectl get nodes
	# Create deployment
	#kubectl create deployment tiddlyhost-minikube --image=base
	kubectl get deployments
	PODNAME=$$(kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') && echo $$PODNAME

# Try to be smart about how to run the tests
# TODO: Refactor and integrate with "shell" and "join"
tests:
	@if [[ -z $$(docker-compose ps --services --filter status=running | grep base ) ]]; then \
	  echo Starting new container to run tests...; \
	  docker-compose run --rm base bin/rails test\:all; \
	else \
	  echo Running tests in existing container...; \
	  docker-compose exec base bin/rails test\:all; \
	fi

# Stop and remove containers
cleanup:
	docker-compose stop
	docker-compose rm -f

# Generate an SSL cert
# (If the cert exists, assume the key exists too.)
cert: etc/certs/localssl.cert

etc/certs/localssl.cert:
	@cd ./etc && ./create-local-ssl-cert.sh

clear-cert:
	@rm ./etc/certs/localssl.cert
	@rm ./etc/certs/localssl.key

redo-cert: clear-cert cert

github-url:
	@echo https://github.com/simonbaird/tiddlyhost
