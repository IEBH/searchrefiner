plugin_dirs := $(wildcard plugin/*/)
plugin_obs := $(foreach plugin,$(plugin_dirs),$(plugin)plugin.so)
plugin_src := $(patsubst %plugin.so,%*.go,$(plugin_obs))
quicklearn_bin := resources/quickrank/bin/quicklearn
go_source = *.go cmd/searchrefiner/*.go
SERVER = server

plugin: $(plugin_obs)
.PHONY: run plugin clean quicklearn docker-shell docker-run docker-deploy

# These compile the quicklearn binary, which are required for the QueryLens plugin.
$(quicklearn_bin):
	@git clone --recursive https://github.com/hpclab/quickrank.git
	@cd quickrank && mkdir build_ && cd build_ && cmake .. -DCMAKE_CXX_COMPILER=g++-5 -DCMAKE_BUILD_TYPE=Release && make
	@mv quickrank resources/quickrank

quicklearn: $(quicklearn_bin)

# The main server compilation step. It depends on the compilation of any plugins that exist.
$(SERVER): $(plugin_obs) $(go_source)
	go build -o server cmd/searchrefiner/server.go

# The plugins are just shared object files that should only need to be recompiled if changed.
.SECONDEXPANSION:
$(plugin_obs): $$(patsubst %plugin.so,%*.go,$$@)
	go build -buildmode=plugin -o $@ $^

# Running the server may optionally depend on quicklearn.
run: quicklearn $(SERVER)
	@mkdir -p plugin_storage
	@./server

clean:
	@[ -f server ] && rm $(foreach plugin,$(plugin_obs),$(plugin)) server || true

docker-build:
	docker build -t ielab-searchrefiner .
	-docker network rm search-refiner-net
	docker network create search-refiner-net --driver=bridge

# Deploy a SearchRefiner docker setup on the SRA server
docker-deploy:
	docker run --rm --net=search-refiner-net --publish=8001:4853/tcp --publish=8080:80/tcp  --name=sr-1 ielab-searchrefiner
	# docker run --rm --net=search-refiner-net --publish=8002:4853/tcp --publish=8080:80/tcp --name=sr-2 ielab-searchrefiner
	# docker run --rm --net=search-refiner-net --publish=8003:4853/tcp --publish=8080:80/tcp --name=sr-3 ielab-searchrefiner
	# docker run --rm --net=search-refiner-net --publish=8004:4853/tcp --publish=8080:80/tcp --name=sr-4 ielab-searchrefiner

# Run the SearchRefiner in the foreground on the local terminal
docker-run:
	-docker run --rm --net=search-refiner-net --publish=8001:4853/tcp --publish=8080:80/tcp --name=sr-1 ielab-searchrefiner

# Dial into a paused SearchRefiner instance (use ./server to run)
docker-shell:
	-docker run --rm --net=search-refiner-net --publish=8001:4853/tcp --publish=8080:80/tcp --name=sr-1 -it ielab-searchrefiner /bin/sh
